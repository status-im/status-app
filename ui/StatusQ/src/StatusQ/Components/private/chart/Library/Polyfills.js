.pragma library

/*!
    /This file is used to provide the necessary polyfills for Chart.js to work in QML
    /It is loaded before Chart.js and fills the global object with the necessary functions
    /to make Chart.js work in QML.

    /The following polyfills are provided:
    /- requestAnimationFrame https://developer.mozilla.org/en-US/docs/Web/API/window/requestAnimationFrame
    /- window https://developer.mozilla.org/en-US/docs/Web/API/window

!*/

(function(global){
    // ChartJs needs a global object to work. Simulating the window object
    global.window = global

    var _animator = Qt.createComponent("Animator.qml").createObject()
    // TODO: Find a way to use the canvas `requestAnimation`
    global.requestAnimationFrame = function(callback) {
        return _animator.requestAnimation(callback)
    }
})(this)
