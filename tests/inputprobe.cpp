// SPDX-License-Identifier: GPL-2.0-or-later
// Loaded only into the private test compositor; never included in the RPM.
#include <plugin.h>
#include <workspace.h>
#include <window.h>
#include <input.h>
#include <pointer_input.h>
#include <wayland_server.h>
#include <wayland/seat.h>
#include <QDBusConnection>
#include <chrono>
using namespace KWin;
class InputProbe : public Plugin {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface","org.vela.InputProbe")
    static auto now() {return std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now().time_since_epoch());}
public:
    InputProbe() {
        waylandServer()->seat()->setHasPointer(true);waylandServer()->seat()->setHasKeyboard(true);
        auto bus=QDBusConnection::sessionBus();bus.registerService("org.vela.InputProbe");bus.registerObject("/InputProbe",this,QDBusConnection::ExportAllSlots);
    }
public Q_SLOTS:
    void motion(double x,double y) {input()->pointer()->processMotionAbsolute({x,y},now());input()->pointer()->processFrame(nullptr);}
    void relative(double x,double y) {input()->pointer()->processMotion({x,y},{x,y},now(),nullptr);input()->pointer()->processFrame(nullptr);}
    void button(int code,bool pressed) {input()->pointer()->processButton(code,pressed?PointerButtonState::Pressed:PointerButtonState::Released,now());input()->pointer()->processFrame(nullptr);}
    bool hover(const QString &caption) {
        for(auto w:workspace()->windows()) if(w->caption()==caption) {workspace()->activateWindow(w);auto center=w->frameGeometry().center();motion(center.x(),center.y());return true;}
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
        if(qEnvironmentVariable("VELA_TEST_SESSION")!="1") return {};
        return std::make_unique<InputProbe>();
    }
};
#include "inputprobe.moc"
