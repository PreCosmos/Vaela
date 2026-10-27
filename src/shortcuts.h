// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QHash>
#include <QKeySequence>
#include <QList>
#include <QString>
#include <Qt>

// Keys Vaela takes before Plasma's global shortcuts, only while a layout that uses them is active.
// Meta+Left/Right focus rather than quick-tile in both tiling layouts: Vaela owns the geometry there.
struct LayoutKey {
    QString id, label, keys; // keys: the default, as QKeySequence portable text
    bool tiled, scrollable;  // the layouts it works in
};
inline const QList<LayoutKey> &layoutKeys() {
    static const QList<LayoutKey> keys{
        {"widen", "Widen the active column", "Meta++", true, true},
        {"narrow", "Narrow the active column", "Meta+-", true, true},
        {"focus-previous", "Focus the window to the left", "Meta+Left", true, true},
        {"focus-next", "Focus the window to the right", "Meta+Right", true, true},
        {"column-left", "Move the column left", "Meta+Ctrl+Left", false, true},
        {"column-right", "Move the column right", "Meta+Ctrl+Right", false, true}};
    return keys;
}
// custom: the user's keys by id, where "none" turns a key off; ids not in it keep their default.
inline QString columnShortcut(Qt::Key key, Qt::KeyboardModifiers modifiers, bool tiled, bool scrollable,
                              const QHash<QString, QString> &custom = {}) {
    modifiers &= ~Qt::KeypadModifier;
    const QKeySequence pressed(QKeyCombination(modifiers, key));
    for(const auto &k : layoutKeys()) {
        if(!(tiled && k.tiled) && !(scrollable && k.scrollable)) continue;
        if(custom.contains(k.id)) {
            if(custom[k.id] != "none" && QKeySequence(custom[k.id]) == pressed) return k.id;
            continue;
        }
        // Plus shares the = key on many layouts, so it counts with or without Shift.
        if(k.id == "widen" ? (key == Qt::Key_Plus || key == Qt::Key_Equal) && (modifiers & ~Qt::ShiftModifier) == Qt::MetaModifier
                           : QKeySequence(k.keys) == pressed)
            return k.id;
    }
    return {};
}
