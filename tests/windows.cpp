// SPDX-License-Identifier: GPL-2.0-or-later
#include <QGuiApplication>
#include <QQuickWindow>
#include <QDBusInterface>
#include <QTimer>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
int main(int argc,char **argv) {
    QGuiApplication app(argc,argv);
    QQuickWindow a,b,c,transient;
    int i=0;
    for(auto w:{&a,&b,&c}) {w->setTitle(QStringLiteral("Vaela test %1").arg(++i));w->resize(400,300);w->setColor(Qt::darkBlue);w->show();}
    QDBusInterface controller("org.vaela.Controller","/Controller","org.vaela.Controller");
    QDBusInterface probe("org.vaela.InputProbe","/InputProbe","org.vaela.InputProbe");
    auto geometry=[&](const QQuickWindow &w) {
        auto object=QJsonDocument::fromJson(probe.call("geometry",w.title()).arguments().first().toString().toUtf8()).object();
        return QRectF(object["x"].toDouble(),object["y"].toDouble(),object["w"].toDouble(),object["h"].toDouble());
    };
    bool passed=true;double beforeA=0,beforeB=0,beforeC=0;
    auto check=[&](bool ok,const char *message){if(!ok){qCritical()<<message<<a.size()<<b.size()<<c.size();passed=false;}};
    QTimer::singleShot(800,[&]{controller.call("setMode","Auto Tiling");});
    QTimer::singleShot(1600,[&]{
        // Three windows: two side by side, and the third alone in the last row, across the whole width.
        for(auto w:{&a,&b}) check(w->width()>500 && w->width()<700 && w->height()<500,"Tiling did not resize the window into a grid");
        check(c.width()>1200 && c.height()<500,"The last row did not span the whole width");
        probe.call("hover",a.title());
        controller.call("action","widen");
    });
    QTimer::singleShot(2000,[&]{controller.call("action","taller");});
    QTimer::singleShot(2400,[&]{
        check(a.width()>700 && b.width()<600 && c.width()>1200,"Resizing a tiled column did not adjust its neighbours");
        auto ra=geometry(a),rb=geometry(b),rc=geometry(c);
        check(!ra.intersects(rb) && !ra.intersects(rc) && !rb.intersects(rc),"Tiled windows overlap after resizing");
        check(qAbs(rb.x()-ra.right()-8)<2 && qAbs(rc.y()-ra.bottom()-8)<2 && qAbs(rc.x()-ra.x())<2,"Tiled neighbours did not preserve their gaps");
        check(a.height()>c.height() && a.height()==b.height(),"Resizing a tiled row did not adjust all row neighbours");
        // The Scrollable steps below act on the newest window again.
        probe.call("hover",c.title());
        controller.call("setMode","Scrollable");
    });
    QTimer::singleShot(2800,[&]{
        transient.setTitle("Vaela transient test");transient.setTransientParent(&c);
        transient.resize(320,180);transient.show();
    });
    QTimer::singleShot(3200,[&]{
        check(transient.size()==QSize(320,180),"Transient window was tiled as a column");
        transient.close();
        for(auto w:{&a,&b,&c}) check(w->width()>750 && w->width()<900 && w->height()>650,"Scrollable did not create full-height columns");
        controller.call("action","narrow");
    });
    QTimer::singleShot(4000,[&]{
        check(c.width()<800 && a.width()>800 && b.width()>800,"Scrollable did not retain an independent resized column");
        auto ra=geometry(a),rb=geometry(b),rc=geometry(c);
        check(!ra.intersects(rb) && !rb.intersects(rc) && !ra.intersects(rc),"Scrollable columns overlap after resizing");
        check(qAbs(rb.x()-ra.right()-8)<2 && qAbs(rc.x()-rb.right()-8)<2,"Scrollable neighbours did not move to preserve gaps");
        controller.call("action","focus-previous");
    });
    QTimer::singleShot(4800,[&]{
        check(c.width()<800,"Scrollable column width reset on focus change");
        controller.call("action","column-left");
    });
    QTimer::singleShot(5200,[&]{
        const auto reply=controller.call("state");
        auto state=QJsonDocument::fromJson(reply.arguments().first().toString().toUtf8()).object();
        for(auto entry:state["desktops"].toArray()) if(entry.toObject()["current"].toBool()) {
            auto windows=entry.toObject()["windows"].toArray();
            check(windows.size()==3 && windows[0].toString()=="Vaela test 2" && windows[1].toString()=="Vaela test 1","Column move did not reorder the strip");
        }
        controller.call("action","column-right");
    });
    QTimer::singleShot(5600,[&]{
        const auto reply=controller.call("state");
        auto state=QJsonDocument::fromJson(reply.arguments().first().toString().toUtf8()).object();
        for(auto entry:state["desktops"].toArray()) if(entry.toObject()["current"].toBool()) {
            auto windows=entry.toObject()["windows"].toArray();
            check(windows.size()==3 && windows[0].toString()=="Vaela test 1" && windows[1].toString()=="Vaela test 2","Column move right did not restore strip order");
        }
        controller.call("setMode","Float");
    });
    QTimer::singleShot(6400,[&]{
        for(auto w:{&a,&b,&c}) check(w->size()==QSize(400,300),"Float did not restore the saved size");
        controller.call("setMode","Auto Tiling");
    });
    QTimer::singleShot(7200,[&]{
        beforeA=a.width();beforeB=b.width();
        check(probe.call("beginResize",a.title()).arguments().first().toBool(),"Could not begin native tile resize");
    });
    QTimer::singleShot(7400,[&]{check(probe.call("stepResize",a.title(),80.,0.).arguments().first().toBool(),"Native tile resize did not start");});
    QTimer::singleShot(8000,[&]{
        check(a.width()>beforeA && b.width()<beforeB,"Tiled neighbours did not resize during the active drag");
        probe.call("endResize");
    });
    QTimer::singleShot(8400,[&]{
        auto ra=geometry(a),rb=geometry(b),rc=geometry(c);
        check(!ra.intersects(rb) && !ra.intersects(rc) && !rb.intersects(rc),"Native tile resize left overlaps");
        controller.call("setMode","Scrollable");
    });
    QTimer::singleShot(9200,[&]{
        beforeA=a.width();beforeB=b.width();beforeC=c.width();
        check(probe.call("beginResize",c.title()).arguments().first().toBool(),"Could not begin native column resize");
    });
    QTimer::singleShot(9400,[&]{check(probe.call("stepResize",c.title(),100.,0.).arguments().first().toBool(),"Native column resize did not start");});
    QTimer::singleShot(10000,[&]{
        if(!(c.width()>beforeC && a.width()==beforeA && b.width()==beforeB)) qCritical()<<"widths before the drag"<<beforeA<<beforeB<<beforeC;
        check(c.width()>beforeC && a.width()==beforeA && b.width()==beforeB,"Native column resize changed independent widths");
        auto ra=geometry(a),rb=geometry(b),rc=geometry(c);
        check(qAbs(rb.x()-ra.right()-8)<2 && qAbs(rc.x()-rb.right()-8)<2,"Columns did not follow the active resize without gaps or overlaps");
        probe.call("endResize");
    });
    QTimer::singleShot(10400,[&]{
        auto ra=geometry(a),rb=geometry(b),rc=geometry(c);
        check(!ra.intersects(rb) && !ra.intersects(rc) && !rb.intersects(rc),"Native column resize left overlaps");
        controller.call("setMode","Float");
    });
    QTimer::singleShot(10800,[&]{app.exit(passed?0:1);});
    return app.exec();
}
