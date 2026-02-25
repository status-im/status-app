.import "Polyfills.js" as Polyfills
.import "Chart.bundle.js" as ChartJs
.import "chartjs-plugin-crosshair.js" as CrosshairLib
.import "chartjs-plugin-datalabels.js" as DataLabelsLib

.import StatusQ.Core.Theme as SQTheme


/*! 
    /This file is used to provide the necessary wrappers for Chart.js to work in QML
    /It is loaded after Chart.js and plugins and provides the necessary functions
    /NOTE: Some plugins work out of the box, others need to be adapted to work in QML
!*/

(function(global){
    Chart.helpers.merge(Chart.defaults.global, {
        // Default options
        events: [
            "mousemove",
            "mouseout",
            "click"
        ]
    })

    // QML rendering plugin
    Chart.plugins.register({
        afterDraw: function(chart) {
            chart.canvas.requestPaint()
        }
    })

    var EVENTS = {
       /*chartJS event: QML event*/
        click: "clicked",
        mousemove: "positionChanged",
        mouseenter: "entered",
        mouseout: "exited",
        mousedown: "pressed",
        mouseup: "released",
        resize: "resized"
    }

    function createEvent(type, chart, x, y, native, target) {
        return {
            type: type,
            chart: chart,
            native: native || null,
            x: x !== undefined ? x : null,
            y: y !== undefined ? y : null,
            target: target || null,
        }
    }

    // QML platform implementation
    Chart.helpers.merge(Chart.platform, {
        addEventListener: function(chart, type, listener) {
            const mapped = EVENTS[type]
            if (!mapped) {
                console.warn("Unsupported event:", type)
                return
            }

            const canvas = chart.canvas
            const qmlHandler = (event) => {
                listener(createEvent(
                    type,
                    chart,
                    event && event.x,
                    event && event.y,
                    event,
                    canvas))
            }
            
            canvas._eventSource[mapped].connect(qmlHandler)
            canvas._eventSource.connectedHandlers[listener] = qmlHandler
        },

        removeEventListener: function(chart, type, listener) {
            const canvas = chart.canvas
            if (!canvas._eventSource.connectedHandlers[listener]) {
                return
            }

            const mapped = EVENTS[type]
            const qmlHandler = canvas._eventSource.connectedHandlers[listener]
            canvas._eventSource[mapped].disconnect(qmlHandler)
            delete canvas._eventSource.connectedHandlers[listener]
        }
    })

    Chart.helpers.merge(Chart.helpers, {
        color: function(c) {
            return Color(c)
        },
        getHoverColor: function(c) {
            if (!SQTheme || !SQTheme.Theme || !SQTheme.Theme.palette) {
                return Color(c)
            }
            const hoverColor = SQTheme.Theme.palette.hoverColor(c)
            if (!hoverColor) {
                return Color(c)
            }

            return hoverColor
        }
    })

    Chart.helpers.merge(Chart.prototype, {
        // Resync chart internals with current canvas size, then update
        resize: function(silent) {
            var me = this
            if (!me.canvas) {
                return
            }
           
            var opts = me.options
            var h = Math.max(0, me.canvas.height)
            var w = Math.max(0, me.canvas.width)

            if (h === me.height && w === me.width) {
                return
            }

            me.height = h
            me.width = w

            if (silent) { 
                return
            }

            // Notify any plugins about the resize
            var size = {width: w, height: h}
            Chart.plugins.notify(me, "resize", [size])

            // Notify of resize
            if (opts.onResize) {
                opts.onResize(me, newSize)
            }

            me.stop()
            me.update(opts.responsiveAnimationDuration)
        }
    })
})(this)
