// SPDX-License-Identifier: GPL-2.0-or-later
#include "gestures.h"
#include "layout.h"
#include "shortcuts.h"
#include <QSet>
#include <plugin.h>
#include <input.h>
#include <input_event.h>
#include <pointer_input.h>
#include <workspace.h>
#include <window.h>
#include <virtualdesktops.h>
#include <wayland_server.h>
#include <wayland/seat.h>
#include <activities.h>
#include <KConfigGroup>
#include <KSharedConfig>
#include <KGlobalAccel>
#include <KGlobalShortcutInfo>
#include <QAction>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QElapsedTimer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QRegion>
#include <QTimer>
#include <algorithm>
#include <utility>
using namespace KWin;

class Vaela : public Plugin, public InputEventFilter {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.vaela.Controller")
    KSharedConfig::Ptr config = KSharedConfig::openConfig("vaelarc");
    QTimer hold, layoutTimer, backgroundTimer;
    QString lastBackgrounds;
    QElapsedTimer hoverClock;
    Gesture gesture;
    QPointer<Window> target, lastWindow;
    bool down = false, radial = false, arranging = false;
    QHash<Window *, RectF> floating;
    QHash<Window *, double> scrollWidths;
    QHash<QString, QVector<double>> columns, rows;
    QSet<Window *> resizing;
    QList<Window *> windowOrder;
    QHash<quint32,QString> capturedKeys;
    QList<QAction *> globals;
    QString recording; // the shortcut Vaela Settings waits to record from the next key press
    QString layoutKey(Window *w) const {
        return activity()+":"+VirtualDesktopManager::self()->currentDesktop()->id()+":"+QString::number(quintptr(w->output()),16);
    }
    // The monitors Vaela runs on: "primary" (the default), "all", or a comma-separated list of
    // output names. A list that names no connected monitor falls back to the primary one.
    bool covers(LogicalOutput *output) const {
        const auto order=workspace()->outputOrder();
        if(!output || order.isEmpty()) return false;
        const QString choice=KConfigGroup(config,"General").readEntry("Monitors",QStringLiteral("primary"));
        if(choice=="all") return true;
        const auto names=choice.split(',',Qt::SkipEmptyParts);
        if(std::none_of(order.begin(),order.end(),[&](LogicalOutput *o){return names.contains(o->name());})) return output==order.first();
        return names.contains(output->name());
    }
    // Where views opened from the keyboard appear: the active monitor, if Vaela runs there.
    QPointF home() const {
        auto output=workspace()->activeOutput();
        if(!covers(output)) for(auto o:workspace()->outputOrder()) if(covers(o)) {output=o;break;}
        return output ? output->geometryF().center() : QPointF();
    }
    void rememberResize(Window *w, QSizeF requested = {}) {
        if(!eligible(w) || mode()=="Float" || !covers(w->output())) return;
        const QRectF area=workspace()->clientArea(MaximizeArea,w->output());
        if(!requested.isValid()) requested=w->frameGeometry().size();
        if(mode()=="Scrollable") {
            scrollWidths[w]=std::clamp(requested.width(),120.,area.width()*2);
            return;
        }
        QList<Window*> list;
        for(auto win:windowOrder) if(eligible(win) && win->output()==w->output()) list.append(win);
        int index=list.indexOf(w); if(index<0) return;
        int nc=int(std::ceil(std::sqrt(list.size()))), nr=(list.size()+nc-1)/nc;
        double gap=KConfigGroup(config,"General").readEntry("Gap",8);
        auto key=layoutKey(w);
        auto widths=Layout::sizes(columns.value(key),nc,area.width()-gap*(nc+1));
        auto heights=Layout::sizes(rows.value(key),nr,area.height()-gap*(nr+1));
        columns[key]=Layout::resize(widths,index%nc,requested.width(),120);
        rows[key]=Layout::resize(heights,index/nc,requested.height(),100);
    }
    QString appId(Window *w) const { auto id=w->desktopFileName(); return id.isEmpty() ? w->resourceClass() : id; }
    // Scrollable column widths outlive their windows, per application, as a share of the screen width.
    double storedWidth(Window *w, const QRectF &area) const {
        const double share=KConfigGroup(config,"ScrollableWidths").readEntry(appId(w),0.);
        return share>0 ? std::clamp(share*area.width(),120.,area.width()*2) : std::max(240.,area.width()*.65);
    }
    void saveWidth(Window *w) {
        if(mode()!="Scrollable" || !scrollWidths.contains(w) || appId(w).isEmpty()) return;
        const QRectF area=workspace()->clientArea(MaximizeArea,w->output());
        KConfigGroup(config,"ScrollableWidths").writeEntry(appId(w),scrollWidths[w]/area.width());config->sync();
    }
    QString activity() const { auto a=workspace()->activities(); return a && !a->current().isEmpty() ? a->current() : QStringLiteral("default"); }
    QString mode(VirtualDesktop *desktop = nullptr) const {
        if(!desktop) desktop=VirtualDesktopManager::self()->currentDesktop();
        KConfigGroup group(config,"Layouts");
        return group.readEntry(activity()+":"+desktop->id(),group.readEntry(activity(),QStringLiteral("Float")));
    }
    bool locked() const { return waylandServer() && waylandServer()->isScreenLocked(); }
    void shell(const QString &method, const QVariantList &args) {
        auto m=QDBusMessage::createMethodCall("org.vaela.Shell", "/Shell", "org.vaela.Shell", method);
        m.setArguments(args); QDBusConnection::sessionBus().asyncCall(m);
    }
    void ui(QString view, QPointF pos = {}) {
        if(pos.isNull()) pos=home();
        shell("showView",{view,int(pos.x()),int(pos.y())});
    }
    void stopHold() {hold.stop();}
    void contextClick() {
        auto seat=waylandServer()->seat();
        seat->notifyPointerButton(Qt::RightButton,PointerButtonState::Pressed);seat->notifyPointerFrame();
        seat->notifyPointerButton(Qt::RightButton,PointerButtonState::Released);seat->notifyPointerFrame();
    }
    // oldDefault: a shortcut this action used to ship with; a saved copy of it moves to the new key.
    void shortcut(QString id, QString key, std::function<void()> fn, QString oldDefault = {}) {
        auto a=new QAction(id,this); a->setObjectName(id); a->setProperty("componentName", "vaela");
        KGlobalAccel::self()->setDefaultShortcut(a,{QKeySequence(key)});
        KGlobalAccel::self()->setShortcut(a,{QKeySequence(key)});
        if(!oldDefault.isEmpty() && KGlobalAccel::self()->shortcut(a)==QList<QKeySequence>{QKeySequence(oldDefault)})
            KGlobalAccel::self()->setShortcut(a,{QKeySequence(key)},KGlobalAccel::NoAutoloading);
        connect(a,&QAction::triggered,this,[this,fn]{if(!locked()) fn();});
        globals.append(a);
    }
    QAction *globalAction(const QString &id) const {
        for(auto a:globals) if(a->objectName()==id) return a;
        return nullptr;
    }
    static const LayoutKey *findLayoutKey(const QString &id) {
        for(const auto &k:layoutKeys()) if(k.id==id) return &k;
        return nullptr;
    }
    static QString keyText(const QList<QKeySequence> &keys) {return keys.isEmpty() ? QString() : keys.first().toString(QKeySequence::PortableText);}
    QHash<QString,QString> customLayoutKeys() const {
        QHash<QString,QString> custom; KConfigGroup group(config,"Shortcuts");
        for(const auto &k:layoutKeys()) if(group.hasKey(k.id)) custom[k.id]=group.readEntry(k.id,k.keys);
        return custom;
    }
    QString layoutKeyText(const LayoutKey &k) const {
        const auto keys=KConfigGroup(config,"Shortcuts").readEntry(k.id,k.keys);
        return keys=="none" ? QString() : keys;
    }
    // What else answers to keys: another Vaela shortcut, or for global ones another application.
    QString conflict(const QString &id, const QKeySequence &keys) const {
        for(auto a:globals) if(a->objectName()!=id && KGlobalAccel::self()->shortcut(a).contains(keys)) return "Vaela: "+a->text();
        for(const auto &k:layoutKeys()) if(k.id!=id && QKeySequence(layoutKeyText(k))==keys) return "Vaela: "+k.label;
        // Layout keys take over Plasma's keys on purpose, and only while their layout is active.
        if(findLayoutKey(id)) return {};
        for(const auto &info:KGlobalAccel::globalShortcutsByKey(keys))
            if(info.componentUniqueName()!="vaela") return info.componentFriendlyName()+": "+info.friendlyName();
        return {};
    }
    void assign(const QString &id, const QKeySequence &keys) {
        if(auto a=globalAction(id)) KGlobalAccel::self()->setShortcut(a,keys.isEmpty() ? QList<QKeySequence>{} : QList<QKeySequence>{keys},KGlobalAccel::NoAutoloading);
        else if(findLayoutKey(id)) {KConfigGroup(config,"Shortcuts").writeEntry(id,keys.isEmpty() ? QStringLiteral("none") : keys.toString(QKeySequence::PortableText));config->sync();}
    }
    static bool modifierKey(Qt::Key key) {
        return QList<Qt::Key>{Qt::Key_Shift,Qt::Key_Control,Qt::Key_Meta,Qt::Key_Alt,Qt::Key_AltGr,Qt::Key_Super_L,Qt::Key_Super_R,Qt::Key_Hyper_L,Qt::Key_Hyper_R}.contains(key);
    }
    void schedule() { backgroundTimer.start(); if(!arranging) layoutTimer.start(); }
    QString backgroundKey(VirtualDesktop *desktop) const {return activity()+":"+desktop->id();}
    // Whether windows hide most of a monitor, so a video behind them can pause.
    bool occluded(LogicalOutput *output) const {
        const QRect screen=QRectF(output->geometryF()).toAlignedRect();
        QRegion covered;
        for(auto w:workspace()->stackingOrder())
            if(appWindow(w) && w->isShown() && !w->isMinimized() && w->isOnCurrentDesktop() && w->isOnCurrentActivity())
                covered+=QRectF(w->frameGeometry()).toAlignedRect().intersected(screen);
        qint64 area=0;
        for(const QRect &r:covered) area+=qint64(r.width())*r.height();
        return area*100>=qint64(screen.width())*screen.height()*85;
    }
    void updateBackgrounds() {
        const auto json=backgrounds();
        if(json!=lastBackgrounds) {lastBackgrounds=json;Q_EMIT backgroundsChanged(json);}
    }
    bool appWindow(Window *w) const { return w && w->isNormalWindow() && !w->isSpecialWindow() && !w->isInternal() && !w->inherits("KWin::LayerShellV1Window") && w->resourceClass()!="vaela-shell"; }
    bool eligible(Window *w) const {
        return appWindow(w) && w->isMovable() && w->isResizable()
            && w->isOnCurrentDesktop() && w->isOnCurrentActivity() && !w->isOnAllDesktops()
            && !w->isMinimized() && !w->isFullScreen();
    }
    void watch(Window *w) {
        windowOrder.append(w);
        connect(w,&Window::minimizedChanged,this,[this]{schedule();});
        connect(w,&Window::desktopsChanged,this,[this]{schedule();});
        connect(w,&Window::fullScreenChanged,this,[this]{schedule();});
        connect(w,&Window::frameGeometryChanged,this,[this]{backgroundTimer.start();});
        connect(w,&Window::hiddenChanged,this,[this]{backgroundTimer.start();});
        connect(w,&Window::interactiveMoveResizeStarted,this,[this,w]{if(w->isInteractiveResize()) resizing.insert(w);});
        connect(w,&Window::interactiveMoveResizeStepped,this,[this,w](const RectF &geometry){
            // KWin can report the start before the operation counts as a resize; pick it up here too,
            // otherwise the next arrange snaps the window back mid-drag.
            if(!arranging && w->isInteractiveResize()) {resizing.insert(w);rememberResize(w,geometry.size());schedule();}
        });
        connect(w,&Window::interactiveMoveResizeFinished,this,[this,w]{if(resizing.remove(w)) {rememberResize(w,w->moveResizeGeometry().size());saveWidth(w);}schedule();});
        schedule();
    }
    void arrange() {
        if (locked()) return;
        if (mode()=="Float") {
            for(auto it=floating.begin();it!=floating.end();) {
                if(it.key()->isOnCurrentActivity() && it.key()->isOnCurrentDesktop()) {it.key()->moveResize(it.value());it=floating.erase(it);} else ++it;
            }
            return;
        }
        arranging=true;
        const auto all=windowOrder;
        QHash<LogicalOutput *, QList<Window *>> groups;
        for(auto w:all) if(eligible(w)) groups[w->output()].append(w);
        for(auto it=groups.begin();it!=groups.end();++it) {
            const auto list=it.value();
            // Monitors Vaela does not run on float; tiled windows moved there get their old size back.
            if(!covers(it.key())) {
                for(auto w:list) if(floating.contains(w) && !resizing.contains(w) && !w->isInteractiveMove()) {
                    auto r=floating.take(w);
                    // A window dragged over from a tiled monitor stays where it was dropped.
                    if(!it.key()->geometryF().contains(r.center())) r.moveCenter(w->frameGeometry().center());
                    w->moveResize(r);
                }
                continue;
            }
            const QRectF area=workspace()->clientArea(MaximizeArea,it.key());
            const double gap=KConfigGroup(config,"General").readEntry("Gap",8);
            const bool scroll=mode()=="Scrollable";
            const int cols=scroll ? list.size() : int(std::ceil(std::sqrt(list.size())));
            const int rows=scroll ? 1 : (list.size()+cols-1)/cols;
            auto key=layoutKey(list.first());
            auto widths=Layout::sizes(columns.value(key),cols,area.width()-gap*(cols+1));
            auto heights=Layout::sizes(this->rows.value(key),rows,area.height()-gap*(rows+1));
            // A remembered width seeds each column once, so resizing one window never resizes
            // other open windows of the same application.
            if(scroll) for(int i=0;i<list.size();++i) {
                if(!scrollWidths.contains(list[i])) scrollWidths[list[i]]=storedWidth(list[i],area);
                widths[i]=scrollWidths[list[i]];
            }
            QVector<double> xs(cols),ys(rows);
            double total=gap;
            for(int i=0;i<cols;++i) {xs[i]=total;total+=widths[i]+gap;}
            double y=gap;
            for(int i=0;i<rows;++i) {ys[i]=y;y+=heights[i]+gap;}
            int focus=std::max(0,int(list.indexOf(lastWindow)));
            // The focused column always sits in the middle of the screen, so new windows open centred.
            double offset=scroll ? xs[focus]-(area.width()-widths[focus])/2 : 0;
            if(scroll) for(int i=0;i<list.size();++i) if(resizing.contains(list[i])) offset=area.x()+xs[i]-list[i]->moveResizeGeometry().x();
            for(int i=0;i<list.size();++i) {
                auto w=list[i]; if(!floating.contains(w)) floating[w]=w->frameGeometry();
                if(resizing.contains(w)) continue;
                if(w->maximizeMode()!=MaximizeRestore) w->setMaximize(false,false);
                w->moveResize(RectF(area.x()+xs[i%cols]-offset,area.y()+ys[i/cols],widths[i%cols],heights[i/cols]));
            }
        }
        arranging=false;
    }
public:
    Vaela() : InputEventFilter(InputFilterOrder::TabBox) {
        if(qEnvironmentVariable("VAELA_SESSION")!="1") return;
        input()->installInputEventFilter(this);
        QDBusConnection::sessionBus().registerService("org.vaela.Controller");
        QDBusConnection::sessionBus().registerObject("/Controller",this,QDBusConnection::ExportAllSlots|QDBusConnection::ExportAllSignals);
        connect(waylandServer(),&WaylandServer::lockStateChanged,this,[this]{stopHold();down=false;radial=false;target=nullptr;capturedKeys.clear();recording.clear();backgroundTimer.start();});
        // Window moves and resizes arrive in bursts; the wallpaper hears the outcome once.
        backgroundTimer.setSingleShot(true); backgroundTimer.setInterval(60);
        connect(&backgroundTimer,&QTimer::timeout,this,&Vaela::updateBackgrounds);
        connect(VirtualDesktopManager::self(),&VirtualDesktopManager::desktopRemoved,this,[this](VirtualDesktop *desktop){
            KConfigGroup group(config,"Backgrounds");
            for(const auto &key:group.keyList()) if(key.endsWith(":"+desktop->id())) group.deleteEntry(key);
            config->sync();schedule();
        });
        // A still right-button hold opens the radial menu; a quick click becomes the app's context click on release.
        hold.setTimerType(Qt::PreciseTimer);
        hold.setSingleShot(true);
        connect(&hold,&QTimer::timeout,this,[this]{if(down && !gesture.moved && !locked()) {radial=true;ui("radial",gesture.start);}});
        layoutTimer.setSingleShot(true); layoutTimer.setInterval(40);
        connect(&layoutTimer,&QTimer::timeout,this,&Vaela::arrange);
        connect(workspace(),&Workspace::windowAdded,this,&Vaela::watch);
        connect(workspace(),&Workspace::windowRemoved,this,[this](Window*w){windowOrder.removeAll(w);floating.remove(w);scrollWidths.remove(w);resizing.remove(w);schedule();});
        connect(workspace(),&Workspace::windowActivated,this,[this](Window *w){if(appWindow(w)) lastWindow=w;schedule();});
        lastWindow=workspace()->activeWindow();
        connect(workspace(),&Workspace::currentDesktopChanged,this,[this]{schedule();});
        connect(workspace(),&Workspace::currentActivityChanged,this,[this]{schedule();});
        connect(workspace(),&Workspace::outputOrderChanged,this,[this]{schedule();});
        for(auto w:workspace()->windows()) watch(w);
        shortcut("Quick Commands","F2",[this]{ui("commands");});
        shortcut("Vaela Settings","Meta+Ctrl+S",[this]{ui("settings");});
        shortcut("Cycle Vaela Layout","Meta+Ctrl+Space",[this]{action("cycle-layout");});
        // Meta+Ctrl+R until 0.6, which Spectacle uses for window recording.
        shortcut("Vaela Radial Menu","Meta+Ctrl+M",[this]{ui("radial");},"Meta+Ctrl+R");
        shortcut("Scroll to Previous Window","Meta+Alt+Left",[this]{action("focus-previous");});
        shortcut("Scroll to Next Window","Meta+Alt+Right",[this]{action("focus-next");});
        shortcut("Widen Vaela Window","Meta+Ctrl+Alt+Right",[this]{action("widen");});
        shortcut("Narrow Vaela Window","Meta+Ctrl+Alt+Left",[this]{action("narrow");});
        shortcut("Grow Vaela Row","Meta+Ctrl+Alt+Down",[this]{action("taller");});
        shortcut("Shrink Vaela Row","Meta+Ctrl+Alt+Up",[this]{action("shorter");});
    }
    bool keyboardKey(KeyboardKeyEvent *e) override {
        if(qEnvironmentVariable("VAELA_SESSION")!="1" || locked()) return false;
        if(e->state==KeyboardKeyState::Released) return capturedKeys.remove(e->nativeScanCode)>0;
        // The same modifiers KWin matches global shortcuts with, so a recorded key works as one.
        const auto modifiers=e->modifiersRelevantForGlobalShortcuts & ~Qt::KeypadModifier;
        if(!recording.isEmpty() && !modifierKey(e->key)) {
            const auto id=std::exchange(recording,QString());
            capturedKeys[e->nativeScanCode]=id;
            // Esc cancels and Backspace removes the shortcut, unless held with modifiers.
            if(e->key==Qt::Key_Escape && !modifiers) shell("shortcutChanged",{id,QString(),QString()});
            else setShortcut(id,e->key==Qt::Key_Backspace && !modifiers ? QString() : QKeySequence(QKeyCombination(modifiers,e->key)).toString(QKeySequence::PortableText),false);
            return true;
        }
        if(!covers(workspace()->activeOutput())) return capturedKeys.contains(e->nativeScanCode);
        const auto command=columnShortcut(e->key,modifiers,mode()=="Auto Tiling",mode()=="Scrollable",customLayoutKeys());
        if(command.isEmpty()) return capturedKeys.contains(e->nativeScanCode);
        // Run before KGlobalAccel: Plasma's zoom and workspace defaults share these keys.
        capturedKeys[e->nativeScanCode]=command;action(command);return true;
    }
    bool pointerButton(PointerButtonEvent *e) override {
        if(qEnvironmentVariable("VAELA_SESSION")!="1") return false;
        if(locked()) {stopHold();down=false;radial=false;return false;}
        if(e->button!=Qt::RightButton) return false;
        if(e->state==PointerButtonState::Pressed) {
            config->reparseConfiguration();
            if(!KConfigGroup(config,"General").readEntry("Gestures",true) || e->modifiers.testFlag(Qt::ShiftModifier)
                || !covers(workspace()->outputAt(e->position))) return false;
            gesture.begin(e->position);down=true;radial=false;target=nullptr;
            auto stack=workspace()->stackingOrder();
            for(auto it=stack.crbegin();it!=stack.crend();++it) {
                auto w=*it;
                if(w->isOnCurrentDesktop() && w->isOnCurrentActivity() && !w->isMinimized() && w->frameGeometry().contains(e->position)) {
                    // Let shell UI, panels and desktop handle their own context menus.
                    if(!appWindow(w) && !w->isDesktop()) {down=false;return false;}
                    if(appWindow(w)) {target=w;workspace()->activateWindow(w);}
                    break;
                }
            }
            hold.start(std::clamp(KConfigGroup(config,"General").readEntry("RadialDelay",500),150,2000));return true;
        }
        if(!down) return false;
        down=false;stopHold();
        if(radial) {radial=false; ui("radial-release",e->position);return true;}
        if(!gesture.directions.isEmpty()) {
            static const QHash<QString,QString> actions={{"L","previous"},{"R","next"},{"U","maximize"},{"D","close"},{"DR","close"},{"UD","cycle-layout"},{"DU","terminal"},{"UL","activities"},{"UR","commands"},{"RU","send-next"},{"LU","send-previous"}};
            action(KConfigGroup(config,"Bindings").readEntry(gesture.directions,actions.value(gesture.directions)));
        } else {
            // Send a balanced click without changing the physical button state in KWin.
            contextClick();
        }
        target=nullptr; return true;
    }
    bool pointerMotion(PointerMotionEvent *e) override {
        if(!down) return false;
        if(locked()) {down=false;stopHold();return false;}
        if(radial) {
            // While the button is held KWin keeps the pointer on the pressed window, so the
            // radial menu gets no hover events of its own; send it the position instead.
            if(!hoverClock.isValid() || hoverClock.elapsed()>=16) {hoverClock.restart();ui("radial-hover",e->position);}
            return false;
        }
        gesture.update(e->position,std::clamp(KConfigGroup(config,"General").readEntry("Threshold",28),12,120));
        if(gesture.moved) stopHold();
        return true;
    }
public Q_SLOTS:
    void reload() {config->reparseConfiguration();schedule();}
    QString state() {
        if(locked()) return "{}";
        QJsonArray desks;
        for(auto d:VirtualDesktopManager::self()->desktops()) {
            QJsonArray windows;
            for(auto w:windowOrder) if(appWindow(w) && w->isOnDesktop(d) && w->isOnCurrentActivity()) windows.append(w->caption());
            desks.append(QJsonObject{{"id",int(d->x11DesktopNumber())},{"name",d->name()},{"mode",mode(d)},{"current",d==VirtualDesktopManager::self()->currentDesktop()},{"windows",windows},
                                     {"background",KConfigGroup(config,"Backgrounds").readEntry(backgroundKey(d),QString())}});
        }
        QJsonArray outputs; const auto order=workspace()->outputOrder();
        for(auto o:order) {
            const auto label=(o->manufacturer()+" "+o->model()).trimmed();
            outputs.append(QJsonObject{{"name",o->name()},{"label",label.isEmpty() ? o->name() : label},{"primary",o==order.first()},{"covered",covers(o)}});
        }
        QJsonArray keys;
        for(auto a:globals) keys.append(QJsonObject{{"id",a->objectName()},{"label",a->text()},{"keys",keyText(KGlobalAccel::self()->shortcut(a))},{"default",keyText(KGlobalAccel::self()->defaultShortcut(a))}});
        for(const auto &k:layoutKeys()) keys.append(QJsonObject{{"id",k.id},{"label",k.label},{"keys",layoutKeyText(k)},{"default",k.keys},{"layout",k.tiled ? "Auto Tiling and Scrollable" : "Scrollable"}});
        return QString::fromUtf8(QJsonDocument(QJsonObject{{"version",QStringLiteral(VAELA_VERSION)},{"mode",mode()},{"desktops",desks},{"activity",activity()},
                                                           {"outputs",outputs},{"shortcuts",keys},{"backgrounds",int(KConfigGroup(config,"Backgrounds").keyList().size())}}).toJson(QJsonDocument::Compact));
    }
    // What the Vaela wallpaper shows on each monitor Vaela covers, with the playback settings.
    QString backgrounds() {
        const KConfigGroup general(config,"General");
        const auto source=KConfigGroup(config,"Backgrounds").readEntry(backgroundKey(VirtualDesktopManager::self()->currentDesktop()),QString());
        QJsonObject outputs; bool audio=true;
        for(auto o:workspace()->outputOrder()) if(covers(o)) {
            outputs[o->name()]=QJsonObject{{"source",source},{"occluded",occluded(o)},{"audio",audio}};
            audio=false; // one monitor plays the sound, so the same video on several does not echo
        }
        return QString::fromUtf8(QJsonDocument(QJsonObject{{"outputs",outputs},{"locked",locked()},
            {"fill",general.readEntry("BackgroundFill",QStringLiteral("fill"))},{"muted",general.readEntry("BackgroundMuted",true)},
            {"volume",general.readEntry("BackgroundVolume",50)},{"speed",general.readEntry("BackgroundSpeed",100)},
            {"dim",general.readEntry("BackgroundDim",0)},{"blur",general.readEntry("BackgroundBlur",0)},
            {"transition",general.readEntry("BackgroundTransition",600)},{"pauseCovered",general.readEntry("PauseWhenCovered",true)},
            {"pauseOnBattery",general.readEntry("PauseOnBattery",true)}}).toJson(QJsonDocument::Compact));
    }
    // url "" removes the workspace's background in the current activity.
    void setBackground(int id, const QString &url) {
        if(locked()) return;
        for(auto d:VirtualDesktopManager::self()->desktops()) if(int(d->x11DesktopNumber())==id) {
            KConfigGroup group(config,"Backgrounds");
            if(url.isEmpty()) group.deleteEntry(backgroundKey(d)); else group.writeEntry(backgroundKey(d),url);
            config->sync();updateBackgrounds();
        }
    }
    void setMode(const QString &value) {
        if(locked() || !QStringList{"Float","Auto Tiling","Scrollable"}.contains(value)) return;
        KConfigGroup(config,"Layouts").writeEntry(activity()+":"+VirtualDesktopManager::self()->currentDesktop()->id(),value);config->sync();
        schedule();
    }
    // Vaela Settings: the next key press becomes this shortcut; "" stops waiting.
    void recordShortcut(const QString &id) {recording=locked() || (!globalAction(id) && !findLayoutKey(id)) ? QString() : id;}
    // keys "" removes the shortcut. Keys something else uses are only taken with replace; otherwise
    // the shell hears who has them and can ask.
    void setShortcut(const QString &id, const QString &keys, bool replace) {
        if(locked() || (!globalAction(id) && !findLayoutKey(id))) return;
        const QKeySequence sequence(keys);
        const auto clash=sequence.isEmpty() ? QString() : conflict(id,sequence);
        if(!clash.isEmpty() && !replace) {shell("shortcutChanged",{id,keys,clash});return;}
        if(!clash.isEmpty()) {
            for(auto a:globals) if(a->objectName()!=id && KGlobalAccel::self()->shortcut(a).contains(sequence)) assign(a->objectName(),{});
            for(const auto &k:layoutKeys()) if(k.id!=id && QKeySequence(layoutKeyText(k))==sequence) assign(k.id,{});
            if(!findLayoutKey(id)) KGlobalAccel::stealShortcutSystemwide(sequence);
        }
        assign(id,sequence);
        shell("shortcutChanged",{id,keys,QString()});
    }
    void desktop(int id) {if(!locked()) VirtualDesktopManager::self()->setCurrent(id);}
    void addDesktop() {if(!locked()){auto m=VirtualDesktopManager::self();m->createVirtualDesktop(m->desktops().size(),"Workspace");m->save();}}
    void renameDesktop(int id,const QString &name) {
        if(locked() || name.trimmed().isEmpty()) return;
        for(auto d:VirtualDesktopManager::self()->desktops()) if(int(d->x11DesktopNumber())==id) {d->setName(name.left(80));VirtualDesktopManager::self()->save();}
    }
    void removeDesktop(int id) {
        auto m=VirtualDesktopManager::self(); if(locked() || m->desktops().size()<2) return;
        for(auto d:m->desktops()) if(int(d->x11DesktopNumber())==id) {m->removeVirtualDesktop(d);m->save();break;}
    }
    void action(const QString &name) {
        if(locked()) return;
        auto m=VirtualDesktopManager::self(); auto desks=m->desktops(); auto current=m->currentDesktop();
        int index=desks.indexOf(current);
        auto w=target ? target.data() : lastWindow.data();
        target=nullptr;
        if(name=="next" || name=="previous" || name=="send-next" || name=="send-previous") {
            auto dest=desks[(index+(name.endsWith("previous")?desks.size()-1:1))%desks.size()];
            if(name.startsWith("send")) {if(appWindow(w)) w->setDesktops({dest});} else m->setCurrent(dest);
        } else if(name=="cycle-layout") {QStringList modes{"Float","Auto Tiling","Scrollable"};setMode(modes[(modes.indexOf(mode())+1)%3]);}
        else if(name=="focus-next" || name=="focus-previous") {
            QList<Window*> list; for(auto win:windowOrder) if(eligible(win) && win->output()==workspace()->activeOutput()) list.append(win);
            if(!list.isEmpty()) {
                int next=std::max(0,int(list.indexOf(w)))+(name=="focus-next"?1:-1);
                // The Scrollable strip stops at its ends; the other layouts wrap around.
                next=mode()=="Scrollable" ? std::clamp(next,0,int(list.size())-1) : (next+int(list.size()))%int(list.size());
                workspace()->activateWindow(list[next]);
            }
        } else if(name=="column-left" || name=="column-right") {
            if(mode()!="Scrollable" || !w || !eligible(w)) return;
            QList<Window*> list; for(auto win:windowOrder) if(eligible(win) && win->output()==w->output()) list.append(win);
            int index=list.indexOf(w), neighbour=index+(name=="column-left"?-1:1);
            if(index>=0 && neighbour>=0 && neighbour<list.size()) {
                windowOrder.swapItemsAt(windowOrder.indexOf(w),windowOrder.indexOf(list[neighbour]));schedule();
            }
        } else if(name=="commands" || name=="settings" || name=="terminal" || name=="files" || name=="browser" || name=="activities" || name=="screenshot") ui(name);
        else if(appWindow(w)) {
            if(QStringList{"widen","narrow","taller","shorter"}.contains(name)) {
                QSizeF size=w->frameGeometry().size();
                if(name=="widen" || name=="narrow") size.setWidth(std::max(120.,size.width()+(name=="widen"?80:-80)));
                else size.setHeight(std::max(100.,size.height()+(name=="taller"?60:-60)));
                if(mode()=="Float" || !covers(w->output())) {auto r=w->frameGeometry();r.setSize(size);w->moveResize(r);}
                else {rememberResize(w,size);saveWidth(w);schedule();}
            }
            if(name=="close") w->closeWindow();
            if(name=="minimize") w->setMinimized(true);
            if(name=="maximize") {bool max=w->maximizeMode()!=MaximizeFull;w->setMaximize(max,max);}
        }
    }
Q_SIGNALS:
    void backgroundsChanged(const QString &json);
};
class Factory : public PluginFactory {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID PluginFactory_iid FILE "vaela.json")
    Q_INTERFACES(KWin::PluginFactory)
public:
    std::unique_ptr<Plugin> create() const override {return std::make_unique<Vaela>();}
};
#include "plugin.moc"
