import QtQuick

import StatusQ.Core

import "./Library/Library.js" as Lib

Canvas {
    id: canvas

    readonly property var availablePlugins: {
        return { datalabels: ChartDataLabels }
    }

    property string type: chartType
    property var options: chartOptions
    property var plugins: []
    property var labels: []
    property var datasets: []

    signal resized()

    function refresh() {
        if (d.instance) {
            Qt.callLater(d.refresh)
        }
    }

    function rebuild() {
        if (available) {
            Qt.callLater(d.rebuild)
        }
    }

    // [WORKAROUND] context.lineWidth > 1 makes the scene graph polish step very slow
    // in case of "Image" render target, so by default let's draw with OpenGL when
    // possible (which seems only possible with "Cooperative" strategy).
    renderTarget: Canvas.FramebufferObject
    renderStrategy: Canvas.Cooperative

    // https://www.w3.org/TR/2012/WD-html5-author-20120329/the-canvas-element.html#the-canvas-element
    implicitHeight: 150
    implicitWidth: 300

    // [polyfill] Element
    readonly property alias clientHeight: canvas.height
    readonly property alias clientWidth: canvas.width

    // [polyfill] canvas.style
    readonly property var style: ({
        height: canvas.height,
        width: canvas.width
    })

    // [polyfill] element.getBoundingClientRect
    // https://developer.mozilla.org/docs/Web/API/Element/getBoundingClientRect
    function getBoundingClientRect() {
        return {top: 0, right: canvas.width, bottom: canvas.height, left: 0}
    }

    /**
        \internal object used to forward events to the Chart.js instance
        \see Library.js for the list of events
     */
    property QtObject _eventSource: QtObject {
        signal resized(var event)
        signal clicked(var event)
        signal positionChanged(var event)
        signal entered(var event)
        signal exited(var event)
        signal pressed(var event)
        signal released(var event)

        property var connectedHandlers: []

        readonly property Connections canvasConn: Connections {
            target: canvas
            function onResized() {
                _eventSource.resized(null)
            }
        }

        readonly property Connections mouseConn: Connections {
            target: mouse
            function onPositionChanged(event) {
                _eventSource.positionChanged(event)
            }
            function onEntered(event) {
                _eventSource.entered(event)
            }
            function onExited(event) {
                _eventSource.exited(event)
            }
            function onPressed(event) {
                _eventSource.pressed(event)
            }
            function onReleased(event) {
                _eventSource.released(event)
            }
        }
    }

    StatusMouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: enabled
    }

    onTypeChanged: rebuild()
    onOptionsChanged: refresh()
    onPluginsChanged: refresh()
    onLabelsChanged: refresh()
    onDatasetsChanged: rebuild()
    onHeightChanged: resized()
    onWidthChanged: resized()
    onAvailableChanged: {
        if (!d.instance) {
            rebuild()
        }
    }

    QtObject {
        id: d

        property var instance: null

        function refresh() {
            instance.config.options = canvas.options
            instance.config.plugins = canvas.plugins
            instance.data.labels = canvas.labels
            instance.update()
        }

        function rebuild() {
            if (instance) {
                instance.destroy()
                instance = null
            }
            var ctx = canvas.getContext('2d');
            if (!ctx) {
                return
            }
            const config = {
                type: canvas.type,
                options: canvas.options,
                plugins: canvas.plugins,
                data: {
                    labels: canvas.labels,
                    datasets: canvas.datasets
                }
            }
            instance = new Chart(ctx, config)
        }
    }

    Component.onDestruction: {
        if (d.instance) {
            d.instance.destroy()
        }
    }
}