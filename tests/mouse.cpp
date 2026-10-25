// SPDX-License-Identifier: GPL-2.0-or-later
#include <QApplication>
#include <QWidget>
#include <QMenu>
#include <QContextMenuEvent>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTest>
class ContextWindow : public QWidget {
    Q_OBJECT
public:
    QMenu menu;
    int shown=0,hidden=0;
    bool closed=false;int presses=0,releases=0;
    ContextWindow() {
        setWindowTitle("Vela mouse test");resize(400,300);menu.addAction("Test context menu");
        connect(&menu,&QMenu::aboutToShow,this,[this]{++shown;});connect(&menu,&QMenu::aboutToHide,this,[this]{++hidden;});
    }
protected:
    void mousePressEvent(QMouseEvent *event) override {if(event->button()==Qt::RightButton) ++presses;QWidget::mousePressEvent(event);}
    void mouseReleaseEvent(QMouseEvent *event) override {if(event->button()==Qt::RightButton) ++releases;QWidget::mouseReleaseEvent(event);}
    void contextMenuEvent(QContextMenuEvent *event) override {menu.popup(event->globalPos());}
    void closeEvent(QCloseEvent *event) override {closed=true;QWidget::closeEvent(event);}
};
class MouseTest : public QObject {
    Q_OBJECT
    ContextWindow window;
    QDBusInterface controller{"org.vela.Controller","/Controller","org.vela.Controller"};
    QDBusInterface probe{"org.vela.InputProbe","/InputProbe","org.vela.InputProbe"};
    void button(bool down) {probe.call("button",273,down);}
    void motion(double x,double y) {probe.call("motion",x,y);}
    int desktop() {
        auto s=QJsonDocument::fromJson(controller.call("state").arguments().first().toString().toUtf8()).object();
        for(auto value:s["desktops"].toArray()) if(value.toObject()["current"].toBool()) return value.toObject()["id"].toInt();
        return 0;
    }
private Q_SLOTS:
    void initTestCase() {
        QVERIFY(probe.isValid());controller.call("addDesktop");controller.call("desktop",1);window.show();QTest::qWait(300);
    }
    void workspaceGesturesThroughInputChain() {
        // Blank space, away from the application window and Vela's panels.
        motion(1100,600);button(true);motion(1170,600);button(false);QTRY_COMPARE(desktop(),2);
        motion(1100,600);button(true);motion(1030,600);button(false);QTRY_COMPARE(desktop(),1);
    }
    void contextMenuAndRadialTiming() {
        QVERIFY(probe.call("hover","Vela mouse test").arguments().first().toBool());QTest::qWait(100);
        button(true);QTest::qWait(180);QCOMPARE(window.shown,0);
        QTRY_COMPARE_WITH_TIMEOUT(window.shown,1,400);
        QTRY_COMPARE_WITH_TIMEOUT(window.hidden,1,600);
        QVERIFY(!probe.call("radialVisible").arguments().first().toBool());
        QTRY_VERIFY_WITH_TIMEOUT(probe.call("radialVisible").arguments().first().toBool(),600);
        button(false);
        // Dismiss the overlay through a normal view change before testing hover targeting.
        QDBusInterface shell("org.vela.Shell","/Shell","org.vela.Shell");shell.call("showView","dismiss",0,0);
    }
    void downGestureClosesHoveredWindow() {
        QVERIFY(probe.call("hover","Vela mouse test").arguments().first().toBool());QTest::qWait(100);
        button(true);
        probe.call("relative",0.,80.);button(false);
        QTRY_VERIFY(window.closed);
    }
};
int main(int argc,char **argv) {QApplication app(argc,argv);app.setQuitOnLastWindowClosed(false);MouseTest test;return QTest::qExec(&test,argc,argv);}
#include "mouse.moc"
