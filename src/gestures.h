// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QPointF>
#include <QString>
#include <cmath>
struct Gesture {
    QPointF start, last;
    QString directions;
    bool moved = false;
    void begin(QPointF p) { start = last = p; directions.clear(); moved = false; }
    void update(QPointF p, double threshold) {
        const auto d = p - last;
        if (std::hypot(p.x()-start.x(), p.y()-start.y()) > 8) moved = true;
        if (std::hypot(d.x(), d.y()) < threshold) return;
        const QChar c = std::abs(d.x()) > std::abs(d.y()) ? (d.x()>0?'R':'L') : (d.y()>0?'D':'U');
        if (directions.isEmpty() || directions.back()!=c) directions += c;
        last = p;
    }
};
