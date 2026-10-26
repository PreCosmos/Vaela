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
#include <wayland/display.h>
#include <linux/input-event-codes.h>
#include <activities.h>
#include <KConfigGroup>
#include <KSharedConfig>
#include <KGlobalAccel>
#include <QAction>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QElapsedTimer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QTimer>
#include <algorithm>
using namespace KWin;

class Vaela : public Plugin, public InputEventFilter {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.vaela.Controller")
    KSharedConfig::Ptr config = KSharedConfig::openConfig("vaelarc");
    QTimer hold, contextShow, contextHide, layoutTimer;
    QElapsedTimer hoverClock;
    Gesture gesture;
    QPointer<Window> target, lastWindow;
    bool down = false, radial = false, contextShown = false, contextDelivered = false, arranging = false;
    QHash<Window *, RectF> floating;
    QHash<Window *, double> scrollWidths;
    QHash<QString, QVector<double>> columns, rows;
    QSet<Window *> resizing;
    QList<Window *> windowOrder;
    QHash<quint32,QString> capturedKeys;
    QString layoutKey(Window *w) const {
        return activity()+":"+VirtualDesktopManager::self()->currentDesktop()->id()+":"+QString::number(quintptr(w->output()),16);
    }
    void rememberResize(Window *w, QSizeF requested = {}) {
        if(!eligible(w) || mode()=="Float") return;
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
    void ui(QString view, QPointF pos = {}) {
        auto m=QDBusMessage::createMethodCall("org.vaela.Shell", "/Shell", "org.vaela.Shell", "showView");
        m << view << int(pos.x()) << int(pos.y()); QDBusConnection::sessionBus().asyncCall(m);
    }
    void stopHold() {hold.stop();contextShow.stop();contextHide.stop();}
    void contextClick() {
        auto seat=waylandServer()->seat();
        seat->notifyPointerButton(Qt::RightButton,PointerButtonState::Pressed);seat->notifyPointerFrame();
        seat->notifyPointerButton(Qt::RightButton,PointerButtonState::Released);seat->notifyPointerFrame();
        contextShown=true;contextDelivered=true;
    }
    void dismissContext() {
        if(!contextShown) return;
        bool dismissed=false;
        const auto windows=workspace()->stackingOrder();
        for(auto it=windows.crbegin();it!=windows.crend();++it) if((*it)->hasPopupGrab()) {(*it)->popupDone();dismissed=true;}
        // Some applications draw their context menu inside the parent surface.
        if(!dismissed) {
            auto seat=waylandServer()->seat();
            seat->notifyKeyboardKey(KEY_ESC,KeyboardKeyState::Pressed,waylandServer()->display()->nextSerial());
            seat->notifyKeyboardKey(KEY_ESC,KeyboardKeyState::Released,waylandServer()->display()->nextSerial());
        }
        contextShown=false;
    }
    void shortcut(QString id, QString key, std::function<void()> fn) {
        auto a=new QAction(id,this); a->setObjectName(id); a->setProperty("componentName", "vaela");
        KGlobalAccel::self()->setDefaultShortcut(a,{QKeySequence(key)});
        KGlobalAccel::self()->setShortcut(a,{QKeySequence(key)});
        connect(a,&QAction::triggered,this,[this,fn]{if(!locked()) fn();});
    }
    void schedule() { if(!arranging) layoutTimer.start(); }
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
        QDBusConnection::sessionBus().registerObject("/Controller",this,QDBusConnection::ExportAllSlots);
        connect(waylandServer(),&WaylandServer::lockStateChanged,this,[this]{stopHold();down=false;radial=false;contextShown=false;target=nullptr;capturedKeys.clear();});
        hold.setTimerType(Qt::PreciseTimer);contextShow.setTimerType(Qt::PreciseTimer);contextHide.setTimerType(Qt::PreciseTimer);
        hold.setSingleShot(true); hold.setInterval(1000);
        contextShow.setSingleShot(true);contextShow.setInterval(250);
        contextHide.setSingleShot(true);contextHide.setInterval(750);
        connect(&contextShow,&QTimer::timeout,this,[this]{if(down && !gesture.moved && !locked()) contextClick();});
        connect(&contextHide,&QTimer::timeout,this,[this]{if(down && !locked()) dismissContext();});
        connect(&hold,&QTimer::timeout,this,[this]{if(down && !gesture.moved && !locked()) {dismissContext();radial=true;ui("radial",gesture.start);}});
        layoutTimer.setSingleShot(true); layoutTimer.setInterval(40);
        connect(&layoutTimer,&QTimer::timeout,this,&Vaela::arrange);
        connect(workspace(),&Workspace::windowAdded,this,&Vaela::watch);
        connect(workspace(),&Workspace::windowRemoved,this,[this](Window*w){windowOrder.removeAll(w);floating.remove(w);scrollWidths.remove(w);resizing.remove(w);schedule();});
        connect(workspace(),&Workspace::windowActivated,this,[this](Window *w){if(appWindow(w)) lastWindow=w;schedule();});
        lastWindow=workspace()->activeWindow();
        connect(workspace(),&Workspace::currentDesktopChanged,this,[this]{schedule();});
        connect(workspace(),&Workspace::currentActivityChanged,this,[this]{schedule();});
        for(auto w:workspace()->windows()) watch(w);
        shortcut("Quick Commands","F2",[this]{ui("commands");});
        shortcut("Vaela Settings","Meta+Ctrl+S",[this]{ui("settings");});
        shortcut("Cycle Vaela Layout","Meta+Ctrl+Space",[this]{action("cycle-layout");});
        shortcut("Vaela Radial Menu","Meta+Ctrl+R",[this]{ui("radial");});
        shortcut("Scroll to Previous Window","Meta+Alt+Left",[this]{action("focus-previous");});
        shortcut("Widen Vaela Window","Meta+Ctrl+Alt+Right",[this]{action("widen");});
        shortcut("Narrow Vaela Window","Meta+Ctrl+Alt+Left",[this]{action("narrow");});
        shortcut("Grow Vaela Row","Meta+Ctrl+Alt+Down",[this]{action("taller");});
        shortcut("Shrink Vaela Row","Meta+Ctrl+Alt+Up",[this]{action("shorter");});
        shortcut("Scroll to Next Window","Meta+Alt+Right",[this]{action("focus-next");});
    }
    bool keyboardKey(KeyboardKeyEvent *e) override {
        if(qEnvironmentVariable("VAELA_SESSION")!="1" || locked()) return false;
        if(e->state==KeyboardKeyState::Released) return capturedKeys.remove(e->nativeScanCode)>0;
        const auto command=columnShortcut(e->key,e->modifiers,mode()=="Auto Tiling",mode()=="Scrollable");
        if(command.isEmpty()) return capturedKeys.contains(e->nativeScanCode);
        // Run before KGlobalAccel: Plasma's zoom and workspace defaults share these keys.
        capturedKeys[e->nativeScanCode]=command;action(command);return true;
    }
    bool pointerButton(PointerButtonEvent *e) override {
        if(qEnvironmentVariable("VAELA_SESSION")!="1") return false;
        if(locked()) {stopHold();down=false;radial=false;contextShown=false;return false;}
        if(e->button!=Qt::RightButton) return false;
        if(e->state==PointerButtonState::Pressed) {
            config->reparseConfiguration();
            if(!KConfigGroup(config,"General").readEntry("Gestures",true) || e->modifiers.testFlag(Qt::ShiftModifier)) return false;
            gesture.begin(e->position);down=true;radial=false;contextShown=false;contextDelivered=false;target=nullptr;
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
            hold.start();contextShow.start();contextHide.start();return true;
        }
        if(!down) return false;
        down=false;stopHold();
        if(radial) {radial=false; ui("radial-release",e->position);return true;}
        if(!gesture.directions.isEmpty()) {
            static const QHash<QString,QString> actions={{"L","previous"},{"R","next"},{"U","maximize"},{"D","close"},{"DR","close"},{"UD","cycle-layout"},{"DU","terminal"},{"UL","activities"},{"UR","commands"},{"RU","send-next"},{"LU","send-previous"}};
            action(KConfigGroup(config,"Bindings").readEntry(gesture.directions,actions.value(gesture.directions)));
        } else {
            // Send a balanced click without changing the physical button state in KWin.
            if(!contextDelivered) contextClick();
        }
        target=nullptr; return true;
    }
    bool pointerMotion(PointerMotionEvent *e) override {
        if(!down) return false;
        if(locked()) {down=false;stopHold();contextShown=false;return false;}
        if(radial) {
            // While the button is held KWin keeps the pointer on the pressed window, so the
            // radial menu gets no hover events of its own; send it the position instead.
            if(!hoverClock.isValid() || hoverClock.elapsed()>=16) {hoverClock.restart();ui("radial-hover",e->position);}
            return false;
        }
        gesture.update(e->position,std::clamp(KConfigGroup(config,"General").readEntry("Threshold",28),12,120));
        if(gesture.moved) {stopHold();dismissContext();}
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
            desks.append(QJsonObject{{"id",int(d->x11DesktopNumber())},{"name",d->name()},{"mode",mode(d)},{"current",d==VirtualDesktopManager::self()->currentDesktop()},{"windows",windows}});
        }
        return QString::fromUtf8(QJsonDocument(QJsonObject{{"version",QStringLiteral(VAELA_VERSION)},{"mode",mode()},{"desktops",desks},{"activity",activity()}}).toJson(QJsonDocument::Compact));
    }
    void setMode(const QString &value) {
        if(locked() || !QStringList{"Float","Auto Tiling","Scrollable"}.contains(value)) return;
        KConfigGroup(config,"Layouts").writeEntry(activity()+":"+VirtualDesktopManager::self()->currentDesktop()->id(),value);config->sync();
        schedule();
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
                if(mode()=="Float") {auto r=w->frameGeometry();r.setSize(size);w->moveResize(r);}
                else {rememberResize(w,size);saveWidth(w);schedule();}
            }
            if(name=="close") w->closeWindow();
            if(name=="minimize") w->setMinimized(true);
            if(name=="maximize") {bool max=w->maximizeMode()!=MaximizeFull;w->setMaximize(max,max);}
        }
    }
};
class Factory : public PluginFactory {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID PluginFactory_iid FILE "vaela.json")
    Q_INTERFACES(KWin::PluginFactory)
public:
    std::unique_ptr<Plugin> create() const override {return std::make_unique<Vaela>();}
};
#include "plugin.moc"
