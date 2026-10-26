// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QString>
#include <Qt>
inline QString columnShortcut(Qt::Key key, Qt::KeyboardModifiers modifiers, bool tiled, bool scrollable) {
    modifiers &= ~Qt::KeypadModifier;
    if(tiled || scrollable) {
        if((key==Qt::Key_Plus || key==Qt::Key_Equal) && (modifiers & ~Qt::ShiftModifier)==Qt::MetaModifier) return "widen";
        if(key==Qt::Key_Minus && modifiers==Qt::MetaModifier) return "narrow";
    }
    if(scrollable && modifiers==(Qt::ControlModifier|Qt::MetaModifier)) {
        if(key==Qt::Key_Left) return "column-left";
        if(key==Qt::Key_Right) return "column-right";
    }
    // Takes priority over Plasma's quick tiling only while the strip is in use.
    if(scrollable && modifiers==Qt::MetaModifier) {
        if(key==Qt::Key_Left) return "focus-previous";
        if(key==Qt::Key_Right) return "focus-next";
    }
    return {};
}
