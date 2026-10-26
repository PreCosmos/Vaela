// SPDX-License-Identifier: GPL-2.0-or-later
#include "gestures.h"
#include "layout.h"
#include "shortcuts.h"
#include <QtTest>
#include <QKeySequence>
class Gestures : public QObject {
    Q_OBJECT
private Q_SLOTS:
    void defaultShortcuts() {
        QCOMPARE(columnShortcut(Qt::Key_Plus,Qt::MetaModifier,true,false),QString("widen"));
        QCOMPARE(columnShortcut(Qt::Key_Plus,Qt::MetaModifier|Qt::ShiftModifier,false,true),QString("widen"));
        QCOMPARE(columnShortcut(Qt::Key_Minus,Qt::MetaModifier,true,false),QString("narrow"));
        QCOMPARE(columnShortcut(Qt::Key_Minus,Qt::MetaModifier,false,true),QString("narrow"));
        QVERIFY(columnShortcut(Qt::Key_Plus,Qt::MetaModifier,false,false).isEmpty());
        QCOMPARE(columnShortcut(Qt::Key_Left,Qt::MetaModifier|Qt::ControlModifier,false,true),QString("column-left"));
        QCOMPARE(columnShortcut(Qt::Key_Right,Qt::MetaModifier|Qt::ControlModifier,false,true),QString("column-right"));
        QVERIFY(columnShortcut(Qt::Key_Left,Qt::MetaModifier|Qt::ControlModifier,true,false).isEmpty());
        QCOMPARE(columnShortcut(Qt::Key_Left,Qt::MetaModifier,false,true),QString("focus-previous"));
        QCOMPARE(columnShortcut(Qt::Key_Right,Qt::MetaModifier,false,true),QString("focus-next"));
        QVERIFY(columnShortcut(Qt::Key_Left,Qt::MetaModifier,true,false).isEmpty());
        QVERIFY(columnShortcut(Qt::Key_Right,Qt::MetaModifier,false,false).isEmpty());
        QCOMPARE(QKeySequence("Meta++")[0].key(),Qt::Key_Plus);
        QCOMPARE(QKeySequence("Meta+-")[0].key(),Qt::Key_Minus);
        QCOMPARE(QKeySequence("Ctrl+Meta+Left")[0].keyboardModifiers(),Qt::KeyboardModifiers(Qt::ControlModifier|Qt::MetaModifier));
    }
    void customShortcuts() {
        const QHash<QString,QString> custom{{"focus-next","Meta+L"},{"widen","none"},{"column-left","Alt+Shift+Left"}};
        QCOMPARE(columnShortcut(Qt::Key_L,Qt::MetaModifier,false,true,custom),QString("focus-next"));
        QVERIFY(columnShortcut(Qt::Key_Right,Qt::MetaModifier,false,true,custom).isEmpty());
        QVERIFY(columnShortcut(Qt::Key_Plus,Qt::MetaModifier,true,false,custom).isEmpty());
        QCOMPARE(columnShortcut(Qt::Key_Minus,Qt::MetaModifier,true,false,custom),QString("narrow"));
        QCOMPARE(columnShortcut(Qt::Key_Left,Qt::AltModifier|Qt::ShiftModifier,false,true,custom),QString("column-left"));
        QVERIFY(columnShortcut(Qt::Key_L,Qt::MetaModifier,true,false,custom).isEmpty());
        // Recorded keys round-trip through the text Vaela stores.
        QCOMPARE(QKeySequence(QKeySequence(QKeyCombination(Qt::MetaModifier|Qt::ControlModifier,Qt::Key_M)).toString(QKeySequence::PortableText)),QKeySequence("Meta+Ctrl+M"));
    }
    void sharedBoundaryResize() {
        auto tracks=Layout::resize({600,600},0,800,120);
        QCOMPARE(tracks[0],800.);QCOMPARE(tracks[1],400.);
        tracks=Layout::resize({400,400,400},1,1100,120);
        QCOMPARE(tracks[1],960.);QCOMPARE(tracks[0],120.);QCOMPARE(tracks[2],120.);
        QCOMPARE(Layout::resize({1200},0,800,120)[0],1200.);
        auto scaled=Layout::sizes({800,400},2,900);QCOMPARE(scaled[0],600.);QCOMPARE(scaled[1],300.);
    }
    void clickJitter() {Gesture g;g.begin({100,100});g.update({103,102},28);QVERIFY(!g.moved);QVERIFY(g.directions.isEmpty());}
    void closeStroke() {Gesture g;g.begin({0,0});g.update({0,40},28);g.update({0,80},28);g.update({40,80},28);QCOMPARE(g.directions,QString("DR"));QVERIFY(g.moved);}
    void holdCancellation() {Gesture g;g.begin({0,0});g.update({10,0},28);QVERIFY(g.moved);QVERIFY(g.directions.isEmpty());}
    void thresholdAndReset() {Gesture g;g.begin({0,0});g.update({40,0},60);QVERIFY(g.directions.isEmpty());g.update({65,0},60);QCOMPARE(g.directions,QString("R"));g.begin({-100,20});QVERIFY(!g.moved);QVERIFY(g.directions.isEmpty());g.update({-140,20},28);QCOMPARE(g.directions,QString("L"));}
};
QTEST_GUILESS_MAIN(Gestures)
#include "gestures.moc"
