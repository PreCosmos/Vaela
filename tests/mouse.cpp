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
#include <QFile>
#include <QProcess>
#include <QTemporaryDir>
#include <QDir>
#include <QFileInfo>
#include <linux/input-event-codes.h>
class ContextWindow : public QWidget {
    Q_OBJECT
public:
    QMenu menu;
    int shown=0,hidden=0;
    bool closed=false;int presses=0,releases=0,f2Presses=0,rightMoves=0,shiftMoves=0;
    ContextWindow() {
        setWindowTitle("Vaela mouse test");resize(400,300);menu.addAction("Test context menu");
        connect(&menu,&QMenu::aboutToShow,this,[this]{++shown;});connect(&menu,&QMenu::aboutToHide,this,[this]{++hidden;});
    }
protected:
    void keyPressEvent(QKeyEvent *event) override {if(event->key()==Qt::Key_F2) ++f2Presses;QWidget::keyPressEvent(event);}
    void mousePressEvent(QMouseEvent *event) override {if(event->button()==Qt::RightButton) ++presses;QWidget::mousePressEvent(event);}
    void mouseReleaseEvent(QMouseEvent *event) override {if(event->button()==Qt::RightButton) ++releases;QWidget::mouseReleaseEvent(event);}
    void mouseMoveEvent(QMouseEvent *event) override {
        if(event->buttons().testFlag(Qt::RightButton)) {++rightMoves;if(event->modifiers().testFlag(Qt::ShiftModifier)) ++shiftMoves;}
        QWidget::mouseMoveEvent(event);
    }
    void contextMenuEvent(QContextMenuEvent *event) override {menu.popup(event->globalPos());}
    void closeEvent(QCloseEvent *event) override {closed=true;QWidget::closeEvent(event);}
};
class MouseTest : public QObject {
    Q_OBJECT
    ContextWindow window;
    QDBusInterface controller{"org.vaela.Controller","/Controller","org.vaela.Controller"};
    QDBusInterface probe{"org.vaela.InputProbe","/InputProbe","org.vaela.InputProbe"};
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
    void renameShortcutAndCustomization() {
        QVERIFY(probe.call("hover",window.windowTitle()).arguments().first().toBool());
        QTest::qWait(150);
        auto tap=[&](int code) {probe.call("key",code,true);probe.call("key",code,false);};
        tap(KEY_F2);
        QTRY_VERIFY(probe.call("sized",600,520).arguments().first().toString()!="{}");
        QDBusInterface shell("org.vaela.Shell","/Shell","org.vaela.Shell");
        shell.call("showView","dismiss",0,0);
        auto shortcuts=[&] {
            return QJsonDocument::fromJson(controller.call("state").arguments().first().toString().toUtf8()).object()["shortcuts"].toArray();
        };
        for(auto value:shortcuts()) if(value.toObject()["id"]=="Quick Commands") {
            QCOMPARE(value.toObject()["default"].toString(),QString("F2"));
            QCOMPARE(value.toObject()["keys"].toString(),QString("F2"));
        }
        controller.call("setShortcut","Quick Commands","Meta+Ctrl+F3",false);
        probe.call("key",KEY_LEFTMETA,true);probe.call("key",KEY_LEFTCTRL,true);tap(KEY_F3);
        probe.call("key",KEY_LEFTCTRL,false);probe.call("key",KEY_LEFTMETA,false);
        QTRY_VERIFY(probe.call("sized",600,520).arguments().first().toString()!="{}");
        shell.call("showView","dismiss",0,0);
        controller.call("setShortcut","Quick Commands","",false);
        QVERIFY(probe.call("hover",window.windowTitle()).arguments().first().toBool());QTest::qWait(100);
        tap(KEY_F2);QTRY_COMPARE(window.f2Presses,1);
        controller.call("setShortcut","Quick Commands","F2",false);
    }
    void dolphinFileRename() {
        // F2 is Quick Commands by default; remapping it lets Dolphin receive F2 instead.
        controller.call("setShortcut","Quick Commands","Meta+Ctrl+F3",false);
        QTemporaryDir folder(QDir::tempPath()+"/vaela-rename-XXXXXX");
        QVERIFY(folder.isValid());
        QFile file(folder.path()+"/original.txt");QVERIFY(file.open(QIODevice::WriteOnly));file.close();
        QProcess dolphin;
        dolphin.start("dolphin",{"--new-window",folder.path()});
        QVERIFY(dolphin.waitForStarted());
        const QString caption=QFileInfo(folder.path()).fileName()+QStringLiteral(" — Dolphin");
        QTRY_VERIFY_WITH_TIMEOUT(probe.call("hover",caption).arguments().first().toBool(),5000);
        QTest::qWait(500);
        auto tap=[&](int code) {probe.call("key",code,true);probe.call("key",code,false);};
        probe.call("key",KEY_LEFTCTRL,true);tap(KEY_A);probe.call("key",KEY_LEFTCTRL,false);
        tap(KEY_F2);QTest::qWait(250);
        // Dolphin selects the basename and keeps the extension when F2 opens Rename.
        for(int code:{KEY_R,KEY_E,KEY_N,KEY_A,KEY_M,KEY_E,KEY_D}) tap(code);
        tap(KEY_ENTER);
        QTRY_VERIFY_WITH_TIMEOUT(QFile::exists(folder.path()+"/renamed.txt"),3000);
        QVERIFY(!QFile::exists(folder.path()+"/original.txt"));
        dolphin.terminate();dolphin.waitForFinished();
        controller.call("setShortcut","Quick Commands","F2",false);
    }
    void workspaceGesturesThroughInputChain() {
        // Blank space, away from the application window and Vaela's panels.
        motion(1100,600);button(true);motion(1170,600);button(false);QTRY_COMPARE(desktop(),2);
        motion(1100,600);button(true);motion(1030,600);button(false);QTRY_COMPARE(desktop(),1);
    }
    void workspaceButtonsThroughPointerEvents() {
        QVERIFY(probe.call("workspaceBar",false,0).arguments().first().toBool());QTest::qWait(500);
        QVERIFY(probe.call("workspaceBar",true,2).arguments().first().toBool());QTRY_COMPARE(desktop(),2);
        QTest::qWait(400);
        QVERIFY(probe.call("workspaceBar",true,1).arguments().first().toBool());QTRY_COMPARE(desktop(),1);
    }
    void perWorkspaceModes() {
        controller.call("desktop",1);controller.call("setMode","Auto Tiling");
        controller.call("desktop",2);controller.call("setMode","Scrollable");
        controller.call("desktop",1);
        auto s=QJsonDocument::fromJson(controller.call("state").arguments().first().toString().toUtf8()).object();
        QCOMPARE(s["mode"].toString(),QString("Auto Tiling"));
        controller.call("desktop",2);
        s=QJsonDocument::fromJson(controller.call("state").arguments().first().toString().toUtf8()).object();
        QCOMPARE(s["mode"].toString(),QString("Scrollable"));
        controller.call("setMode","Float");controller.call("desktop",1);controller.call("setMode","Float");QTest::qWait(150);
    }
    void quickClickAndRadialHold() {
        QVERIFY(probe.call("hover","Vaela mouse test").arguments().first().toBool());QTest::qWait(100);
        // A quick right-click reaches the application as its own context click, on release.
        button(true);QTest::qWait(120);QCOMPARE(window.shown,0);button(false);
        QTRY_COMPARE_WITH_TIMEOUT(window.shown,1,600);
        window.menu.hide();QTRY_COMPARE_WITH_TIMEOUT(window.hidden,1,600);
        // Holding still opens the radial menu at 0.5 s, with no context menu on the way.
        QVERIFY(probe.call("hover","Vaela mouse test").arguments().first().toBool());QTest::qWait(100);
        button(true);QTest::qWait(300);
        QVERIFY(!probe.call("radialVisible").arguments().first().toBool());
        QTRY_VERIFY_WITH_TIMEOUT(probe.call("radialVisible").arguments().first().toBool(),600);
        QCOMPARE(window.shown,1);
        button(false);
        // Dismiss the overlay through a normal view change before testing hover targeting.
        QDBusInterface shell("org.vaela.Shell","/Shell","org.vaela.Shell");shell.call("showView","dismiss",0,0);
    }
    void shiftRightDragPassesThrough_data() {
        QTest::addColumn<bool>("shiftFirst");QTest::addColumn<bool>("strokeFirst");
        QTest::newRow("shift-before-right")<<true<<false;
        QTest::newRow("shift-after-right")<<false<<false;
        QTest::newRow("shift-after-stroke")<<false<<true;
    }
    void shiftRightDragPassesThrough() {
        QFETCH(bool,shiftFirst);QFETCH(bool,strokeFirst);
        window.setContextMenuPolicy(Qt::NoContextMenu);
        QVERIFY(probe.call("hover","Vaela mouse test").arguments().first().toBool());QTest::qWait(100);
        const int presses=window.presses,releases=window.releases,moves=window.rightMoves,shiftMoves=window.shiftMoves,current=desktop();
        if(shiftFirst) probe.call("key",42,true);
        button(true);
        if(!shiftFirst) {QTest::qWait(50);if(strokeFirst) probe.call("relative",35.,0.);probe.call("key",42,true);}
        QTest::qWait(100);probe.call("relative",35.,10.);
        QTRY_VERIFY(window.shiftMoves>shiftMoves);
        QTest::qWait(650);QVERIFY(!probe.call("radialVisible").arguments().first().toBool());
        probe.call("key",42,false);
        QTest::qWait(50);probe.call("relative",35.,10.);
        QTRY_VERIFY(window.rightMoves>=moves+2);
        button(false);QTRY_COMPARE(window.releases,releases+1);
        QCOMPARE(window.presses,presses+1);QCOMPARE(desktop(),current);QVERIFY(!window.closed);
        window.setContextMenuPolicy(Qt::DefaultContextMenu);
    }
    void downGestureClosesHoveredWindow() {
        QVERIFY(probe.call("hover","Vaela mouse test").arguments().first().toBool());QTest::qWait(100);
        button(true);
        probe.call("relative",0.,80.);button(false);
        QTRY_VERIFY(window.closed);
    }
};
int main(int argc,char **argv) {QApplication app(argc,argv);app.setQuitOnLastWindowClosed(false);MouseTest test;return QTest::qExec(&test,argc,argv);}
#include "mouse.moc"
