pragma Singleton

import QtQuick

/*!
    \qmltype ColorUtils
    \inqmlmodule StatusQ.Core

    Singleton providing color utility functions.
*/
QtObject {
    /*!
        Returns the relative luminance of a color as defined by WCAG 2.1:
        https://www.w3.org/TR/WCAG21/#dfn-relative-luminance

        Coefficients (0.2126, 0.7152, 0.0721) reflect the human eye's
        sensitivity to red, green, and blue respectively. The exponent 2.2
        approximates the sRGB gamma linearization.

        @param color [color] The color to evaluate.
        @return      [real]  Luminance in range [0, 1]. Values > 0.5 are considered light.
    */
    function luminance(color) {
        let r = Math.pow(color.r, 2.2) * 0.2126
        let g = Math.pow(color.g, 2.2) * 0.7152
        let b = Math.pow(color.b, 2.2) * 0.0721
        return r + g + b
    }
}
