// SPDX-License-Identifier: GPL-2.0-or-later
// A KWin effect that draws Vaela's tiled windows only on their own monitor. A Scrollable column
// wider than its monitor, or peeking past its edge, is cut off there instead of appearing on the
// next monitor. The Vaela plugin names each tiled window's monitor in its "vaelaHome" property.
#include <effect/effect.h>
#include <effect/effecthandler.h>
#include <effect/effectwindow.h>
#include <core/output.h>
#include <core/renderviewport.h>
#include <scene/scene.h>
#include <window.h>
using namespace KWin;

class VaelaClip : public Effect {
    Q_OBJECT
public:
    bool isActive() const override {return true;}
    void prePaintWindow(RenderView *view, EffectWindow *w, WindowPrePaintData &data) override {
        // Not drawn here, so it must not hide whatever lies under it either.
        if(view->logicalOutput() && foreign(w,view->logicalOutput()->geometryF())) data.setTranslucent();
        effects->prePaintWindow(view,w,data);
    }
    void paintWindow(const RenderTarget &target, const RenderViewport &viewport, EffectWindow *w, int mask, const Region &region, WindowPaintData &data) override {
        if(foreign(w,viewport.renderRect())) return;
        effects->paintWindow(target,viewport,w,mask,region,data);
    }
private:
    // Whether w is a tiled window and monitor is another one than its own. Thumbnails and window
    // screenshots do not show a whole monitor, so they draw the window as usual.
    static bool foreign(EffectWindow *w, const RectF &monitor) {
        const auto home=w->window() ? w->window()->property("vaelaHome").toString() : QString();
        if(home.isEmpty()) return false;
        auto own=effects->findScreen(home);
        if(!own || own->geometryF()==monitor) return false;
        for(auto output:effects->screens()) if(output->geometryF()==monitor) return true;
        return false;
    }
};

KWIN_EFFECT_FACTORY_SUPPORTED(VaelaClip, "vaelaclip.json", return qEnvironmentVariable("VAELA_SESSION")=="1";)
#include "clip.moc"
