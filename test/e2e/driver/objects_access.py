import logging
import time

import object
import squish

import configs

LOG = logging.getLogger(__name__)


def describe_notification_card_for_log(card) -> str:
    try:
        title = getattr(card, 'title', None)
        chat_key = getattr(card, 'chatKey', None)
        return f'title={title!r} chatKey={chat_key!r}'
    except (RuntimeError, AttributeError, LookupError):
        return repr(card)


def describe_button_for_log(btn) -> str:
    try:
        return (
            f'objectName={getattr(btn, "objectName", None)!r} '
            f'visible={getattr(btn, "visible", None)} enabled={getattr(btn, "enabled", None)}'
        )
    except (RuntimeError, AttributeError, LookupError):
        return repr(btn)


def walk_children(parent, depth: int = 1000):
    for child in object.children(parent):
        yield child
        if depth:
            yield from walk_children(child, depth - 1)


def find_descendant_by_object_name(parent, object_name: str, max_depth: int = 1000):
    """Walk QML tree from parent; Squish often fails waitForObject({container: parentRef, objectName: ...})."""
    if parent is None or not object_name:
        return None
    for child in walk_children(parent, max_depth):
        oname = getattr(child, 'objectName', None)
        if oname is not None and str(oname) == object_name:
            return child
    return None


def is_descendant_of(ancestor, item) -> bool:
    if ancestor is None or item is None:
        return False
    cur = item
    for _ in range(96):
        try:
            if cur is ancestor:
                return True
        except Exception:
            pass
        cur = getattr(cur, 'parent', None)
        if cur is None:
            return False
    return False


def find_notification_button_on_card(card, object_name: str, max_depth: int = 1000):
    """Find StatusButton by objectName on a specific NotificationCard.

    ``object.children`` from a QQuick ``Control`` often does not include ``contentItem`` children,
    so tree-walk from the card misses Accept/Decline. Fallback: ``findAllObjects`` + ancestor or bounds.
    """
    if card is None or not object_name:
        return None

    found = find_descendant_by_object_name(card, object_name, max_depth)
    if found is not None:
        LOG.info(
            'find_notification_button_on_card: %r via tree walk on card %s',
            object_name,
            describe_notification_card_for_log(card),
        )
        return found

    all_named = list(squish.findAllObjects({'objectName': object_name}))
    for btn in all_named:
        if not item_is_visible(btn):
            continue
        if is_descendant_of(card, btn):
            LOG.info(
                'find_notification_button_on_card: %r via ancestor chain on card %s; %s',
                object_name,
                describe_notification_card_for_log(card),
                describe_button_for_log(btn),
            )
            return btn

    try:
        outer = object.globalBounds(card)
    except (RuntimeError, LookupError, AttributeError):
        outer = None
    if outer is None or outer.width <= 0 or outer.height <= 0:
        return None

    for btn in all_named:
        if not item_is_visible(btn):
            continue
        try:
            inner = object.globalBounds(btn)
        except (RuntimeError, LookupError, AttributeError):
            continue
        cx = inner.x + inner.width / 2
        cy = inner.y + inner.height / 2
        if outer.x <= cx <= outer.x + outer.width and outer.y <= cy <= outer.y + outer.height:
            LOG.info(
                'find_notification_button_on_card: %r via bounds on card %s; %s',
                object_name,
                describe_notification_card_for_log(card),
                describe_button_for_log(btn),
            )
            return btn

    LOG.info(
        'find_notification_button_on_card: no %r on card %s (%d global name matches)',
        object_name,
        describe_notification_card_for_log(card),
        len(all_named),
    )
    return None


def item_is_visible(item) -> bool:
    """True only if this item and QQuick ancestors are visible.

    Quick-action StatusButtons stay ``visible: true`` while parent ``RowLayout`` (quickActions)
    is hidden via ``visible: root.actionId !== ""`` — checking only the button lies.
    """
    try:
        cur = item
        for _ in range(64):
            if cur is None:
                return True
            if not bool(getattr(cur, 'visible', True)):
                return False
            try:
                op = getattr(cur, 'opacity', None)
                if op is not None and float(op) <= 0.0:
                    return False
            except (TypeError, ValueError):
                pass
            cur = getattr(cur, 'parent', None)
        return True
    except (RuntimeError, AttributeError, LookupError):
        return False


def wait_for_template(
        real_name_template: dict, value: str, attr_name: str, timeout_sec: int = configs.timeouts.UI_LOAD_TIMEOUT_SEC):
    started_at = time.monotonic()
    while True:
        for obj in squish.findAllObjects(real_name_template):
            values = []
            if hasattr(obj, attr_name):
                current_value = str(getattr(obj, attr_name))
                if current_value == value:
                    return obj
                values.append(current_value)
            if time.monotonic() - started_at > timeout_sec:
                raise RuntimeError(f'Value not found in: {values}')
        time.sleep(1)
