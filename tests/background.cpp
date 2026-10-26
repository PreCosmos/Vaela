// SPDX-License-Identifier: GPL-2.0-or-later
#include "background.h"
#include <QtTest>
class Background : public QObject {
    Q_OBJECT
    static QString state(const QString &extra = {}) {
        return QStringLiteral(R"({"outputs":{"DP-1":{"source":"/videos/sea.webm","occluded":false,"audio":true},)"
                              R"("HDMI-A-1":{"source":"/videos/sea.webm","occluded":true,"audio":false}},"locked":false)") + extra + "}";
    }
private Q_SLOTS:
    void perMonitor() {
        VaelaBackground b; b.setScreenName("DP-1"); b.apply(state());
        QCOMPARE(b.source(),QUrl::fromLocalFile("/videos/sea.webm"));
        QVERIFY(b.playing());
        QCOMPARE(b.volume(),0.);  // muted unless told otherwise
        b.setScreenName("eDP-1");  // a monitor Vaela does not cover
        QVERIFY(b.source().isEmpty());
        QVERIFY(!b.playing());
    }
    void pausing() {
        VaelaBackground covered; covered.setScreenName("HDMI-A-1"); covered.apply(state());
        QVERIFY(!covered.playing());
        covered.apply(state(R"(,"pauseCovered":false)"));
        QVERIFY(covered.playing());
        VaelaBackground front; front.setScreenName("DP-1"); front.apply(state());
        front.setOnBattery(true);
        QVERIFY(!front.playing());
        front.apply(state(R"(,"pauseOnBattery":false)"));
        QVERIFY(front.playing());
        front.apply(QString(state()).replace(R"("locked":false)",R"("locked":true)"));
        QVERIFY(!front.playing());
    }
    void sound() {
        VaelaBackground front; front.setScreenName("DP-1"); front.apply(state(R"(,"muted":false,"volume":80)"));
        QCOMPARE(front.volume(),0.8);
        VaelaBackground other; other.setScreenName("HDMI-A-1"); other.apply(state(R"(,"muted":false,"volume":80)"));
        QCOMPARE(other.volume(),0.);  // one monitor plays the sound
        // Heard videos keep playing behind windows.
        QVERIFY(!other.playing());
        VaelaBackground heard; heard.setScreenName("DP-1");
        heard.apply(QString(state(R"(,"muted":false,"volume":80)")).replace(R"("occluded":false)",R"("occluded":true)"));
        QVERIFY(heard.playing());
    }
    void settingsAreClamped() {
        VaelaBackground b; b.setScreenName("DP-1");
        b.apply(state(R"(,"fill":"stretch","speed":900,"dim":95,"blur":40,"transition":-5)"));
        QCOMPARE(b.fill(),QString("stretch")); QCOMPARE(b.speed(),2.); QCOMPARE(b.dim(),.8); QCOMPARE(b.blur(),.4); QCOMPARE(b.transition(),0);
        b.apply(state(R"(,"fill":"sideways")"));
        QCOMPARE(b.fill(),QString("fill"));
    }
    void kinds() {
        QCOMPARE(VaelaBackground::kind(QUrl::fromLocalFile("/x/clip.webm")),QString("video"));
        QCOMPARE(VaelaBackground::kind(QUrl::fromLocalFile("/x/clip.mkv")),QString("video"));
        QCOMPARE(VaelaBackground::kind(QUrl::fromLocalFile("/x/clip.MP4")),QString("video"));
        QCOMPARE(VaelaBackground::kind(QUrl::fromLocalFile("/x/loop.gif")),QString("animated"));
        QCOMPARE(VaelaBackground::kind(QUrl::fromLocalFile("/x/photo.jpg")),QString("image"));
        QCOMPARE(VaelaBackground::toUrl("file:///x/a.png"),QUrl("file:///x/a.png"));
        QCOMPARE(VaelaBackground::toUrl("/x/a b.png"),QUrl::fromLocalFile("/x/a b.png"));
    }
};
QTEST_GUILESS_MAIN(Background)
#include "background.moc"
