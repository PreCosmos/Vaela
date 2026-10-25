// SPDX-License-Identifier: GPL-2.0-or-later
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusConnectionInterface>
#include <algorithm>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QFile>
#include <QDebug>
#include <QDesktopServices>
#include <QTimer>
#include <QQuickWindow>
#include <QScreen>
#include <QCursor>
#include <KConfigGroup>
#include <KSharedConfig>
#include <LayerShellQt/Window>
#include <LayerShellQt/Shell>
class Bridge : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.vela.Shell")
    Q_PROPERTY(QVariantMap state READ state NOTIFY changed)
    Q_PROPERTY(bool gestures READ gestures NOTIFY changed)
    Q_PROPERTY(int threshold READ threshold NOTIFY changed)
    Q_PROPERTY(int gap READ gap NOTIFY changed)
    Q_PROPERTY(QVariantMap bindings READ bindings NOTIFY changed)
    QVariantMap data;
    KSharedConfig::Ptr config=KSharedConfig::openConfig("velarc");
    bool pending=false, migrationAttempted=false;
public:
    QVariantMap state() const {return data;}
    bool gestures() const {return KConfigGroup(config,"General").readEntry("Gestures",true);}
    int threshold() const {return KConfigGroup(config,"General").readEntry("Threshold",28);}
    int gap() const {return KConfigGroup(config,"General").readEntry("Gap",8);}
    QVariantMap bindings() const {
        QVariantMap result{{"L","previous"},{"R","next"},{"U","maximize"},{"D","minimize"},{"DR","close"},{"UD","cycle-layout"},{"DU","terminal"},{"UL","activities"},{"UR","commands"},{"RU","send-next"},{"LU","send-previous"}};
        KConfigGroup group(config,"Bindings");
        for(auto it=result.begin();it!=result.end();++it) it.value()=group.readEntry(it.key(),it.value().toString());
        return result;
    }
    Q_INVOKABLE void bind(const QString &stroke,const QString &command) {
        if(!bindings().contains(stroke)) return;
        KConfigGroup(config,"Bindings").writeEntry(stroke,command);config->sync();call("reload");emit changed();
    }
    Bridge() {
        auto bus=QDBusConnection::sessionBus();bus.registerService("org.vela.Shell");bus.registerObject("/Shell",this,QDBusConnection::ExportAllSlots);
        auto timer=new QTimer(this); connect(timer,&QTimer::timeout,this,&Bridge::refresh);timer->start(350);refresh();
    }
    Q_INVOKABLE void call(QString method,QVariantList args={}) {
        auto message=QDBusMessage::createMethodCall("org.vela.Controller","/Controller","org.vela.Controller",method);
        message.setArguments(args);QDBusConnection::sessionBus().asyncCall(message);
    }
    Q_INVOKABLE void setting(QString key,QVariant value) {
        if(!QStringList{"Gestures","Threshold","Gap","Dark"}.contains(key)) return;
        KConfigGroup(config,"General").writeEntry(key,value);config->sync();call("reload");emit changed();
    }
    Q_INVOKABLE void launch(QString name) {
        if(name=="terminal") QProcess::startDetached("konsole",{});
        else if(name=="files") QProcess::startDetached("dolphin",{});
        else if(name=="browser") QDesktopServices::openUrl(QUrl("https://www.startpage.com"));
        else if(name=="screenshot") QProcess::startDetached("spectacle",{});
        else if(name=="shortcuts") QProcess::startDetached("systemsettings",{"kcm_keys"});
        else if(name=="system") QProcess::startDetached("systemsettings",{});
        else if(name=="activities") {
            auto message=QDBusMessage::createMethodCall("org.kde.plasmashell","/PlasmaShell","org.kde.PlasmaShell","toggleActivityManager");
            QDBusConnection::sessionBus().asyncCall(message);
        }
    }
    Q_INVOKABLE void layer(QQuickWindow *window, QString kind, int x=0,int y=0) {
        auto layer=LayerShellQt::Window::get(window);
        layer->setLayer(LayerShellQt::Window::LayerTop);
        layer->setExclusiveZone(kind=="top"?34:0);
        layer->setKeyboardInteractivity(kind=="overlay" ? LayerShellQt::Window::KeyboardInteractivityExclusive : LayerShellQt::Window::KeyboardInteractivityNone);
        if(kind=="top") layer->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorTop)|LayerShellQt::Window::AnchorRight);
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
        }
    }
public Q_SLOTS:
    void showView(QString view,int x,int y) {
        if(QStringList{"terminal","files","browser","activities","screenshot"}.contains(view)) launch(view);
        else emit requested(view,x,y);
    }
    void refresh() {
        if(pending) return;
        pending=true;
        auto m=QDBusMessage::createMethodCall("org.vela.Controller","/Controller","org.vela.Controller","state");
        auto watcher=new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(m),this);
        connect(watcher,&QDBusPendingCallWatcher::finished,this,[this,watcher]{
            QDBusPendingReply<QString> reply=*watcher;pending=false;
            const auto next=reply.isError()?QVariantMap{}:QJsonDocument::fromJson(reply.value().toUtf8()).object().toVariantMap();
            if(next!=data){data=next;emit changed();}
            if(!migrationAttempted && !data.isEmpty()) {
                migrationAttempted=true;
                QFile script(QStringLiteral(VELA_QML_PATH).replace("Main.qml","migrate-layout.js"));
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
};
int main(int argc,char**argv) {
    QGuiApplication app(argc,argv);if(qEnvironmentVariable("VELA_SESSION")!="1") return 0;
    app.setApplicationName("vela-shell"); app.setQuitOnLastWindowClosed(false);
    if(QDBusConnection::sessionBus().interface()->isServiceRegistered("org.vela.Shell")) return 0;
    Bridge bridge;QQmlApplicationEngine engine;engine.rootContext()->setContextProperty("vela",&bridge);
    engine.load(QUrl::fromLocalFile(qEnvironmentVariableIsSet("VELA_QML")?qEnvironmentVariable("VELA_QML"):QStringLiteral(VELA_QML_PATH)));
    if(engine.rootObjects().isEmpty()) return 1;
    return app.exec();
}
#include "shell.moc"
