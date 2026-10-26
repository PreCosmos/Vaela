// SPDX-License-Identifier: GPL-2.0-or-later
#include "radialmenu.h"
#include "icons.h"
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDBusConnection>
#include <QDBusAbstractAdaptor>
#include <QDBusInterface>
#include <QDBusConnectionInterface>
#include <algorithm>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QFile>
#include <QMimeDatabase>
#include <QDebug>
#include <QDesktopServices>
#include <QTimer>
#include <QThread>
#include <QPalette>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QScreen>
#include <QCursor>
#include <KConfigGroup>
#include <KSharedConfig>
#include <LayerShellQt/Window>
#include <LayerShellQt/Shell>
class Bridge : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.vaela.Shell")
    Q_PROPERTY(QVariantMap state READ state NOTIFY changed)
    Q_PROPERTY(bool gestures READ gestures NOTIFY changed)
    Q_PROPERTY(int threshold READ threshold NOTIFY changed)
    Q_PROPERTY(int gap READ gap NOTIFY changed)
    Q_PROPERTY(QVariantMap bindings READ bindings NOTIFY changed)
    Q_PROPERTY(int radialDelay READ radialDelay NOTIFY changed)
    Q_PROPERTY(QString monitors READ monitors NOTIFY changed)
    Q_PROPERTY(QVariantMap background READ background NOTIFY changed)
    // The monitors that get a layout switch and a workspace bar, by name.
    Q_PROPERTY(QStringList screens READ screens NOTIFY screensChanged)
    QVariantMap data;
    QStringList screenNames;
    KSharedConfig::Ptr config=KSharedConfig::openConfig("vaelarc");
    bool pending=false, migrationAttempted=false;
    int backgroundCount=-1;
public:
    QVariantMap state() const {return data;}
    bool gestures() const {return KConfigGroup(config,"General").readEntry("Gestures",true);}
    int threshold() const {return KConfigGroup(config,"General").readEntry("Threshold",28);}
    int gap() const {return KConfigGroup(config,"General").readEntry("Gap",8);}
    int radialDelay() const {return std::clamp(KConfigGroup(config,"General").readEntry("RadialDelay",500),150,2000);}
    QString monitors() const {return KConfigGroup(config,"General").readEntry("Monitors",QStringLiteral("primary"));}
    // Playback settings for workspace backgrounds, with their defaults.
    QVariantMap background() const {
        const KConfigGroup general(config,"General");
        return {{"fill",general.readEntry("BackgroundFill",QStringLiteral("fill"))},{"muted",general.readEntry("BackgroundMuted",true)},
                {"volume",general.readEntry("BackgroundVolume",50)},{"speed",general.readEntry("BackgroundSpeed",100)},
                {"dim",general.readEntry("BackgroundDim",0)},{"blur",general.readEntry("BackgroundBlur",0)},
                {"transition",general.readEntry("BackgroundTransition",600)},{"pauseCovered",general.readEntry("PauseWhenCovered",true)},
                {"pauseOnBattery",general.readEntry("PauseOnBattery",true)}};
    }
    // "video", "image" or "" for a background's address, to pick how to preview it.
    Q_INVOKABLE QString mediaKind(const QString &url) const {
        if(url.isEmpty()) return {};
        static const QMimeDatabase mimes;
        const auto mime=mimes.mimeTypeForUrl(QUrl(url));
        return mime.name().startsWith("video/") || mime.inherits("video/x-matroska") ? QStringLiteral("video") : QStringLiteral("image");
    }
    // url "" removes the workspace's background. Plasma's desktops use the Vaela wallpaper while
    // any workspace has one; refresh() hands them back once the last one goes.
    Q_INVOKABLE void setBackground(int desktop,const QString &url) {
        call("setBackground",{desktop,url});
        if(!url.isEmpty()) useVaelaWallpaper(true);
    }
    Q_INVOKABLE void setBackgroundEverywhere(const QString &url) {
        for(const auto &d:data.value("desktops").toList()) call("setBackground",{d.toMap().value("id").toInt(),url});
        useVaelaWallpaper(true);
    }
    // Switches every Plasma desktop to the Vaela wallpaper, keeping its picture for workspaces
    // without a background, or back to the wallpaper it had.
    void useVaelaWallpaper(bool use) {
        static const QString script=QStringLiteral(R"(
const use = %1;
for (const d of desktops()) {
    if (use && d.wallpaperPlugin !== "org.vaela.background") {
        const previous = d.wallpaperPlugin;
        let picture = "";
        if (previous === "org.kde.image") {
            d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
            picture = d.readConfig("Image", "");
        }
        d.currentConfigGroup = ["Wallpaper", "org.vaela.background", "General"];
        d.writeConfig("Previous", previous);
        d.writeConfig("Fallback", picture);
        d.wallpaperPlugin = "org.vaela.background";
    } else if (!use && d.wallpaperPlugin === "org.vaela.background") {
        d.currentConfigGroup = ["Wallpaper", "org.vaela.background", "General"];
        d.wallpaperPlugin = d.readConfig("Previous", "org.kde.image") || "org.kde.image";
    }
}
)");
        auto message=QDBusMessage::createMethodCall("org.kde.plasmashell","/PlasmaShell","org.kde.PlasmaShell","evaluateScript");
        message << script.arg(use ? "true" : "false");
        QDBusConnection::sessionBus().asyncCall(message);
    }
    QStringList screens() const {return screenNames;}
    static QScreen *screenNamed(const QString &name) {
        for(auto screen:QGuiApplication::screens()) if(screen->name()==name) return screen;
        return nullptr;
    }
    // The KWin plugin decides which monitors Vaela covers; a monitor Qt has not announced yet waits.
    void updateScreens() {
        if(data.isEmpty()) return;
        QStringList next;
        for(const auto &output:data.value("outputs").toList()) {
            const auto name=output.toMap().value("name").toString();
            if(output.toMap().value("covered").toBool() && screenNamed(name)) next.append(name);
        }
        if(next!=screenNames) {screenNames=next;emit screensChanged();}
    }
    QVariantMap bindings() const {
        QVariantMap result{{"L","previous"},{"R","next"},{"U","maximize"},{"D","close"},{"DR","close"},{"UD","cycle-layout"},{"DU","terminal"},{"UL","activities"},{"UR","commands"},{"RU","send-next"},{"LU","send-previous"}};
        KConfigGroup group(config,"Bindings");
        for(auto it=result.begin();it!=result.end();++it) it.value()=group.readEntry(it.key(),it.value().toString());
        return result;
    }
    Q_INVOKABLE void bind(const QString &stroke,const QString &command) {
        if(!bindings().contains(stroke)) return;
        KConfigGroup(config,"Bindings").writeEntry(stroke,command);config->sync();call("reload");emit changed();
    }
    Bridge() {
        auto timer=new QTimer(this); connect(timer,&QTimer::timeout,this,&Bridge::refresh);timer->start(350);refresh();
        connect(qApp,&QGuiApplication::screenAdded,this,&Bridge::updateScreens);
        connect(qApp,&QGuiApplication::screenRemoved,this,&Bridge::updateScreens);
    }
    Q_INVOKABLE void call(QString method,QVariantList args={}) {
        auto message=QDBusMessage::createMethodCall("org.vaela.Controller","/Controller","org.vaela.Controller",method);
        // JavaScript numbers arrive as doubles; these D-Bus methods require an int.
        if(QStringList{"desktop","renameDesktop","removeDesktop","setBackground"}.contains(method) && !args.isEmpty()) args[0]=args[0].toInt();
        message.setArguments(args);QDBusConnection::sessionBus().asyncCall(message);
    }
    Q_INVOKABLE void setting(QString key,QVariant value) {
        if(!QStringList{"Gestures","Threshold","Gap","Dark","RadialDelay","Monitors","BackgroundFill","BackgroundMuted","BackgroundVolume",
                        "BackgroundSpeed","BackgroundDim","BackgroundBlur","BackgroundTransition","PauseWhenCovered","PauseOnBattery"}.contains(key)) return;
        KConfigGroup(config,"General").writeEntry(key,value);config->sync();call("reload");emit changed();
    }
    Q_INVOKABLE void launch(QString name) {
        if(name=="terminal") QProcess::startDetached("konsole",{});
        else if(name=="files") QProcess::startDetached("dolphin",{});
        else if(name=="browser") QDesktopServices::openUrl(QUrl("https://www.startpage.com"));
        else if(name=="screenshot") QProcess::startDetached("spectacle",{});
        else if(name=="shortcuts") QProcess::startDetached("systemsettings",{"kcm_keys"});
        else if(name=="system") QProcess::startDetached("systemsettings",{});
        else if(name=="info") QProcess::startDetached("kinfocenter",{});
        else if(name.startsWith("kcm_")) QProcess::startDetached("systemsettings",{name});
        else if(name=="activities") {
            auto message=QDBusMessage::createMethodCall("org.kde.plasmashell","/PlasmaShell","org.kde.PlasmaShell","toggleActivityManager");
            QDBusConnection::sessionBus().asyncCall(message);
        }
    }
    // Places a shell window: the layout switch and workspace bar on the named monitor, overlays
    // centred on x,y. For overlays, returns the top-left corner it got in global coordinates.
    Q_INVOKABLE QPoint layer(QQuickWindow *window, QString kind, int x=0,int y=0, QString screen={}) {
        auto layer=LayerShellQt::Window::get(window);
        if(auto target=screenNamed(screen)) {window->setScreen(target);layer->setScreen(target);}
        // The layout switch opens over Plasma's top bar, which already reserves the space.
        layer->setLayer(kind=="top" ? LayerShellQt::Window::LayerOverlay : LayerShellQt::Window::LayerTop);
        layer->setExclusiveZone(0);
        if(kind=="tabs") layer->setActivateOnShow(false);
        layer->setKeyboardInteractivity(kind=="overlay" ? LayerShellQt::Window::KeyboardInteractivityExclusive : kind=="tabs" ? LayerShellQt::Window::KeyboardInteractivityOnDemand : LayerShellQt::Window::KeyboardInteractivityNone);
        if(kind=="top") {
            // Set in from the corner, which belongs to a maximized window's close button.
            layer->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorTop)|LayerShellQt::Window::AnchorRight);
            layer->setMargins(QMargins(0,0,150,0));
        }
        else if(kind=="tabs") layer->setAnchors(LayerShellQt::Window::AnchorRight);
        else {
            auto screen=QGuiApplication::screenAt(QPoint(x,y));if(!screen) screen=QGuiApplication::screenAt(QCursor::pos());if(!screen) screen=QGuiApplication::primaryScreen();
            window->setScreen(screen);layer->setScreen(screen);
            // Layer-shell placement is relative to the chosen output, including negative-origin monitors.
            auto r=screen->geometry();
            int left=std::clamp(x-r.x()-window->width()/2,0,std::max(0,r.width()-window->width()));
            int top=std::clamp(y-r.y()-window->height()/2,34,std::max(34,r.height()-window->height()));
            layer->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorTop)|LayerShellQt::Window::AnchorLeft);
            layer->setMargins(QMargins(left,top,0,0));
            return {r.x()+left,r.y()+top};
        }
        return {};
    }
public Q_SLOTS:
    void showView(QString view,int x,int y) {
        if(QStringList{"terminal","files","browser","activities","screenshot"}.contains(view)) launch(view);
        else emit requested(view,x,y);
    }
    // From the KWin plugin after recording or setting a shortcut; clash names who else has the keys.
    void shortcutChanged(QString id,QString keys,QString clash) {emit shortcutResult(id,keys,clash);refresh();}
    void refresh() {
        if(pending) return;
        pending=true;
        auto m=QDBusMessage::createMethodCall("org.vaela.Controller","/Controller","org.vaela.Controller","state");
        auto watcher=new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(m),this);
        connect(watcher,&QDBusPendingCallWatcher::finished,this,[this,watcher]{
            QDBusPendingReply<QString> reply=*watcher;pending=false;
            const auto next=reply.isError()?QVariantMap{}:QJsonDocument::fromJson(reply.value().toUtf8()).object().toVariantMap();
            if(next!=data){data=next;emit changed();}
            updateScreens();
            if(!data.isEmpty()) {
                const int count=data.value("backgrounds").toInt();
                if(count==0 && backgroundCount>0) useVaelaWallpaper(false);
                backgroundCount=count;
            }
            if(!migrationAttempted && !data.isEmpty()) {
                migrationAttempted=true;
                QFile script((qEnvironmentVariableIsSet("VAELA_QML")?qEnvironmentVariable("VAELA_QML"):QStringLiteral(VAELA_QML_PATH)).replace("Main.qml","migrate-layout.js"));
                if(script.open(QIODevice::ReadOnly)) {
                    auto message=QDBusMessage::createMethodCall("org.kde.plasmashell","/PlasmaShell","org.kde.PlasmaShell","evaluateScript");
                    message << QString::fromUtf8(script.readAll());
                    QDBusConnection::sessionBus().asyncCall(message);
                }
            }
            watcher->deleteLater();
        });
    }
Q_SIGNALS:
    void changed();
    void requested(QString view,int x,int y);
    void shortcutResult(QString id,QString keys,QString clash);
    void screensChanged();
};
class ShellAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.vaela.Shell")
    Bridge *bridge;
public:
    explicit ShellAdaptor(Bridge *bridge) : QDBusAbstractAdaptor(bridge),bridge(bridge) {}
public Q_SLOTS:
    void showView(const QString &view,int x,int y) {bridge->showView(view,x,y);}
    void shortcutChanged(const QString &id,const QString &keys,const QString &clash) {bridge->shortcutChanged(id,keys,clash);}
    // Scriptable too: qdbus org.vaela.Shell /Shell setBackground 2 file:///path/video.webm
    void setBackground(int desktop,const QString &url) {bridge->setBackground(desktop,url);}
};
int main(int argc,char**argv) {
    QGuiApplication app(argc,argv);
    // Autostart runs under systemd, which does not carry VAELA_SESSION. The KWin plugin
    // registers its service only in a Vaela session, so its presence decides instead.
    auto bus=QDBusConnection::sessionBus().interface();
    for(int i=0;i<200 && !bus->isServiceRegistered("org.vaela.Controller");++i) QThread::msleep(100);
    if(!bus->isServiceRegistered("org.vaela.Controller")) return 0;
    app.setApplicationName("vaela-shell"); app.setQuitOnLastWindowClosed(false);
    if(QDBusConnection::sessionBus().interface()->isServiceRegistered("org.vaela.Shell")) return 0;
    Bridge bridge;
    new ShellAdaptor(&bridge);
    if(!QDBusConnection::sessionBus().registerService("org.vaela.Shell")) return 0;
    QDBusConnection::sessionBus().registerObject("/Shell",&bridge,QDBusConnection::ExportAdaptors);
    RadialMenu radial(KSharedConfig::openConfig("vaelarc"));
    // The shell draws its own dark surfaces; Fusion with a matching palette keeps the stock
    // controls (sliders, combo boxes, menus) consistent with them under any system theme.
    QQuickStyle::setStyle("Fusion");
    QPalette palette;
    const QColor panel("#1c1d23"),surface("#25262e"),text("#ecedf2"),muted("#9b9daa"),accent("#ef6a4f");
    for(auto role:{QPalette::Window,QPalette::Base,QPalette::ToolTipBase}) palette.setColor(role,panel);
    for(auto role:{QPalette::Button,QPalette::AlternateBase,QPalette::Mid}) palette.setColor(role,surface);
    for(auto role:{QPalette::WindowText,QPalette::Text,QPalette::ButtonText,QPalette::ToolTipText,QPalette::BrightText}) palette.setColor(role,text);
    palette.setColor(QPalette::PlaceholderText,muted);
    palette.setColor(QPalette::Light,QColor("#3a3b46"));palette.setColor(QPalette::Dark,QColor("#141519"));palette.setColor(QPalette::Shadow,Qt::black);
    palette.setColor(QPalette::Highlight,accent);palette.setColor(QPalette::HighlightedText,Qt::white);
    palette.setColor(QPalette::Disabled,QPalette::Text,muted);palette.setColor(QPalette::Disabled,QPalette::ButtonText,muted);palette.setColor(QPalette::Disabled,QPalette::WindowText,muted);
    QGuiApplication::setPalette(palette);
    QQmlApplicationEngine engine;
    engine.addImageProvider("menuicons",new MenuIcons);
    engine.rootContext()->setContextProperty("vaela",&bridge);
    engine.rootContext()->setContextProperty("radial",&radial);
    engine.load(QUrl::fromLocalFile(qEnvironmentVariableIsSet("VAELA_QML")?qEnvironmentVariable("VAELA_QML"):QStringLiteral(VAELA_QML_PATH)));
    if(engine.rootObjects().isEmpty()) return 1;
    return app.exec();
}
#include "shell.moc"
