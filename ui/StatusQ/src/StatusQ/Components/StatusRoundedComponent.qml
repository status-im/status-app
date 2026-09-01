import QtQuick
import Qt5Compat.GraphicalEffects
import StatusQ.Core
import StatusQ.Core.Theme

/*!
    \qmltype StatusRoundedComponent
    \inherits Rectangle
    \inqmlmodule StatusQ.Components
    \since StatusQ.Components 0.1
    \brief Base component . Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-rectangle.html}{Rectangle}.

    This is a base component for content wrapped by a Rectangle with an optional Loading animation.

    Example of how to use it:

    \qml
        StatusRoundedComponent {
            isLoading: image.isLoading
            isError: image.isError
            showLoadingIndicator: true

            image.source: "qrc:/demoapp/data/logo-test-image.png"

            StatusImage {
                id: image
                anchors.fill: parent
            }
        }
    \endqml

*/
Rectangle {
    id: root

    /*!
        \qmlproperty bool StatusRoundedComponent::showLoadingIndicator

        Set to \c true to enable the Loading animation.
        Set to \c false to disable the Loading animation.
        \note  When enabled, the animation will be shown only when isLoading is \c true and
        isError is \c false.
    */
    property bool showLoadingIndicator: false

    /*!
        \qmlproperty bool StatusRoundedComponent::isLoading

        Set to \c true when the content is loading.
        Set to \c false when the content is finished loading.
    */
    property bool isLoading: false

    /*!
        \qmlproperty bool StatusRoundedComponent::isError

        Set to \c true when some error occured while loading the content.
        Set to \c false when if the content's state is normal.
    */
    property bool isError: false

    implicitWidth: 40
    implicitHeight: 40
    color: "transparent"
    radius: width / 2
    // The mask is a ShaderEffectSource + OpacityMask + mask Rectangle per instance.
    // Invisible instances (e.g. an unused badge) must not pay for it.
    layer.enabled: root.visible
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            x: root.x; y: root.y
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    Loader {
        anchors.centerIn: parent
        active: showLoadingIndicator && !isError && isLoading
        sourceComponent: StatusLoadingIndicator {
            color: Theme.palette.directColor6
        }
    }
}
