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
    QQuickWindow a,b,c;
    int i=0;
    for(auto w:{&a,&b,&c}) {w->setTitle(QStringLiteral("Vela test %1").arg(++i));w->resize(400,300);w->setColor(Qt::darkBlue);w->show();}
    QDBusInterface controller("org.vela.Controller","/Controller","org.vela.Controller");
    bool passed=true;
    auto check=[&](bool ok,const char *message){if(!ok){qCritical()<<message<<a.size()<<b.size()<<c.size();passed=false;}};
    QTimer::singleShot(800,[&]{controller.call("setMode","Auto Tiling");});
    QTimer::singleShot(1600,[&]{
        for(auto w:{&a,&b,&c}) check(w->width()>500 && w->width()<700 && w->height()<500,"Tiling did not resize the window into a grid");
        controller.call("action","widen");
    });
    QTimer::singleShot(2400,[&]{
        check(c.width()>700 && a.width()==c.width() && b.width()<600,"Resizing a tiled column did not adjust its neighbours");
        controller.call("setMode","Scrollable");
    });
    QTimer::singleShot(3200,[&]{
        for(auto w:{&a,&b,&c}) check(w->width()>750 && w->width()<900 && w->height()>650,"Scrollable did not create full-height columns");
        controller.call("action","narrow");
    });
    QTimer::singleShot(4000,[&]{
        check(c.width()<800 && a.width()>800 && b.width()>800,"Scrollable did not retain an independent resized column");
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
            check(windows.size()==3 && windows[0].toString()=="Vela test 2" && windows[1].toString()=="Vela test 1","Column move did not reorder the strip");
        }
        controller.call("action","column-right");
    });
    QTimer::singleShot(5600,[&]{
        const auto reply=controller.call("state");
        auto state=QJsonDocument::fromJson(reply.arguments().first().toString().toUtf8()).object();
        for(auto entry:state["desktops"].toArray()) if(entry.toObject()["current"].toBool()) {
            auto windows=entry.toObject()["windows"].toArray();
            check(windows.size()==3 && windows[0].toString()=="Vela test 1" && windows[1].toString()=="Vela test 2","Column move right did not restore strip order");
        }
        controller.call("setMode","Float");
    });
    QTimer::singleShot(6400,[&]{
        for(auto w:{&a,&b,&c}) check(w->size()==QSize(400,300),"Float did not restore the saved size");
        app.exit(passed?0:1);
    });
    return app.exec();
}
