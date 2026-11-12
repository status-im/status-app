#pragma once

class QQuickItem;
// Gives a chat text item the StaticText role and its `text` property as
// accessible name. Nothing is created while no assistive technology is
// active; items alive when one starts are updated then.
namespace ChatTextAccessibility {
// Call from the constructor and destructor respectively. `textProperty`
// names the property read as the accessible name.
void track(QQuickItem* item, const char* textProperty = "text");
void untrack(QQuickItem* item);
// Call whenever the item's text changes; reads `text` only when needed.
void update(QQuickItem* item);
}
