#include "StatusQ/statuslayoutstate.h"

/*!
    \qmltype StatusLayoutState
    \inherits QObject
    \inqmlmodule StatusQ.Layout
    \ingroup Layout
    \brief Attached property exposing layout-related state for items hosted by StatusSectionLayout.

    This attached type provides auxiliary state for arbitrary items placed
    inside a \c StatusSectionLayout. It is primarily intended to expose
    shared layout-driven state (such as open/close) that can be observed
    and modified both by the layout itself and by external controllers.

    The attached properties are created per item and are not tied to a
    specific layout instance, allowing the same item to coordinate its
    state consistently across different layouts and reparenting scenarios.
    \endqml
*/
StatusLayoutState::StatusLayoutState(QObject* parent)
    : QObject(parent)
{
}

StatusLayoutState* StatusLayoutState::qmlAttachedProperties(QObject* object)
{
    // One attached instance per QObject that uses it.
    return new StatusLayoutState(object);
}

/*!
    \qmlattachedproperty bool StatusLayoutState::opened
    Indicates whether the attached item is currently opened
    from the layout perspective.
*/
bool StatusLayoutState::opened() const
{
    return m_opened;
}

/*!
    \qmlmethod void StatusLayoutState::setOpened(bool opened)
    Sets the opened state for the attached item.
*/
void StatusLayoutState::setOpened(bool opened)
{
    if (m_opened == opened)
        return;

    m_opened = opened;
    emit openedChanged();
}
