// SPDX-License-Identifier: GPL-2.0-or-later
// Loaded only into the private test compositor; never included in the RPM.
#include <plugin.h>
#include <workspace.h>
#include <window.h>
#include <input.h>
#include <pointer_input.h>
#include <keyboard_input.h>
#include <options.h>
#include <linux/input-event-codes.h>
#include <wayland_server.h>
#include <wayland/seat.h>
#include <QDBusConnection>
#include <QJsonDocument>
#include <QJsonObject>
#include <chrono>
using namespace KWin;
class InputProbe : public Plugin {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface","org.vaela.InputProbe")
    static auto now() {return std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now().time_since_epoch());}
public:
    InputProbe() {
        waylandServer()->seat()->setHasPointer(true);waylandServer()->seat()->setHasKeyboard(true);
        auto bus=QDBusConnection::sessionBus();bus.registerService("org.vaela.InputProbe");bus.registerObject("/InputProbe",this,QDBusConnection::ExportAllSlots);
    }
public Q_SLOTS:
    void motion(double x,double y) {input()->pointer()->processMotionAbsolute({x,y},now());input()->pointer()->processFrame(nullptr);}
    void relative(double x,double y) {input()->pointer()->processMotion({x,y},{x,y},now(),nullptr);input()->pointer()->processFrame(nullptr);}
    void button(int code,bool pressed) {input()->pointer()->processButton(code,pressed?PointerButtonState::Pressed:PointerButtonState::Released,now());input()->pointer()->processFrame(nullptr);}
    void key(int code,bool pressed) {input()->keyboard()->processKey(code,pressed?KeyboardKeyState::Pressed:KeyboardKeyState::Released,now());}
    QString active() {auto w=workspace()->activeWindow();return w?w->caption():QString();}
    // Size of the topmost visible surface at a point, including the shell's layer-shell views.
    QString surfaceAt(double x,double y) {
        const auto stack=workspace()->stackingOrder();
        for(auto it=stack.crbegin();it!=stack.crend();++it) if((*it)->isShown() && (*it)->frameGeometry().contains(QPointF(x,y))) {
            auto r=(*it)->frameGeometry();return QString::fromUtf8(QJsonDocument(QJsonObject{{"w",r.width()},{"h",r.height()}}).toJson(QJsonDocument::Compact));
        }
        return "{}";
    }
    bool hover(const QString &caption) {
        for(auto w:workspace()->windows()) if(w->caption()==caption) {workspace()->activateWindow(w);auto center=w->frameGeometry().center();motion(center.x(),center.y());return true;}
        return false;
    }
    bool beginResize(const QString &caption) {
        for(auto w:workspace()->windows()) if(w->caption()==caption) {
            workspace()->activateWindow(w);
            auto r=w->frameGeometry();motion(r.right()-2,r.bottom()-2);
            workspace()->performWindowOperation(w,Options::ResizeOp);
            return w->isInteractiveResize();
        }
        return false;
    }
    bool stepResize(const QString &caption,double dx,double dy) {
        for(auto w:workspace()->windows()) if(w->caption()==caption && w->isInteractiveResize()) {
            // Move the pointer as a real drag does: KWin recomputes the size from the cursor whenever
            // it re-evaluates the pointer, which would undo a resize that left the cursor behind.
            const auto target=w->moveResizeGeometry().bottomRight()+QPointF(dx,dy);
            motion(target.x(),target.y());return true;
        }
        return false;
    }
    void endResize() {
        input()->keyboard()->processKey(KEY_ENTER,KeyboardKeyState::Pressed,now());
        input()->keyboard()->processKey(KEY_ENTER,KeyboardKeyState::Released,now());
    }
    // Shell surfaces have no caption; find one by its size instead.
    QString sized(int width,int height) {
        for(auto w:workspace()->stackingOrder()) if(w->isShown() && int(w->frameGeometry().width())==width && int(w->frameGeometry().height())==height) {
            auto r=w->frameGeometry();return QString::fromUtf8(QJsonDocument(QJsonObject{{"x",r.x()},{"y",r.y()},{"w",r.width()},{"h",r.height()}}).toJson(QJsonDocument::Compact));
        }
        return "{}";
    }
    QString geometry(const QString &caption) {
        for(auto w:workspace()->windows()) if(w->caption()==caption) {
            auto r=w->frameGeometry();return QString::fromUtf8(QJsonDocument(QJsonObject{{"x",r.x()},{"y",r.y()},{"w",r.width()},{"h",r.height()}}).toJson(QJsonDocument::Compact));
        }
        return "{}";
    }
    bool workspaceBar(bool click,int number) {
        for(auto w:workspace()->windows()) {
            auto r=w->frameGeometry();
            if(w->inherits("KWin::LayerShellV1Window") && r.width()<=300 && r.height()>=120 && w->isShown()) {
                if(!click) motion(r.right()-2,r.center().y());
                else {
                    if(r.width()<200) return false;
                    // Main.qml's bar: 10 px panel margin + 10 px padding, a ~20 px header and 8 px
                    // spacing, then 60 px tabs 6 px apart. Click the name, clear of the ⋮ button.
                    motion(r.x()+80,r.y()+78+(number-1)*66);button(272,true);button(272,false);
                }
                return true;
            }
        }
        return false;
    }
    bool radialVisible() {
        for(auto w:workspace()->windows()) if(w->inherits("KWin::LayerShellV1Window") && w->frameGeometry().width()==440 && w->frameGeometry().height()==440 && w->isShown()) return true;
        return false;
    }
};
class ProbeFactory : public PluginFactory {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID PluginFactory_iid FILE "inputprobe.json")
    Q_INTERFACES(KWin::PluginFactory)
public:
    std::unique_ptr<Plugin> create() const override {
        if(qEnvironmentVariable("VAELA_TEST_SESSION")!="1") return {};
        return std::make_unique<InputProbe>();
    }
};
#include "inputprobe.moc"
