pragma Singleton

import QtQuick
import StatusQ.Core
import StatusQ.Core.Theme
import "./xss.js" as XSS

QtObject {
    id: root

    readonly property string windows: "windows"
    readonly property string linux: "linux"
    readonly property string mac: "osx"
    readonly property string android: "android"
    readonly property string ios: "ios"

    readonly property bool isMobile: isIOS || isAndroid
    readonly property bool isIOS: Qt.platform.os === ios
    readonly property bool isAndroid: Qt.platform.os === android
    readonly property bool isMacOS: Qt.platform.os === mac

    function getAbsolutePosition(node) {
        var returnPos = {};
        returnPos.x = 0;
        returnPos.y = 0;
        if (node !== undefined && node !== null) {
            var parentValue = getAbsolutePosition(node.parent);
            returnPos.x = parentValue.x + node.x;
            returnPos.y = parentValue.y + node.y;
        }
        return returnPos;
    }

    function isValidAddress(inputValue) {
        return inputValue !== "0x" && /^0x[a-fA-F0-9]{40}$/.test(inputValue)
    }

    function isValidEns(inputValue) {
        if (!inputValue) {
            return false
        }
        const isEmail = /(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])/.test(inputValue)
        const isDomain = /(?:(?:(?<thld>[\w\-]*)(?:\.))?(?<sld>[\w\-]*))\.(?<tld>[\w\-]*)/.test(inputValue)
        return isEmail || isDomain || (inputValue.startsWith("@") && inputValue.length > 1)
    }

    function isURL(text) {
        return (/https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}(\.[a-zA-Z0-9()]{1,6})?\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)/.test(text))
    }

    function uuid() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 5)
    }

    function getThemeAccountColor(c, accountColors) {
        const upperCaseColor = c.toUpperCase()
        let colorIndex = accountColors.indexOf(upperCaseColor)

        if (colorIndex > -1) {
            return upperCaseColor
        }
        return false
    }

    function findAssetByChainAndSymbol(chainIdToFind, assets, symbolToFind) {
        for(var i=0; i<assets.rowCount(); i++) {
            const item = ModelUtils.get(assets, i)
            if (item.symbol.toLowerCase() === symbolToFind.toLowerCase() &&
                    !!ModelUtils.getByKey(item.balances, "chainId", chainIdToFind)) {
                return {
                    name: item.name,
                    symbol: item.symbol,
                    totalBalance: item.totalBalance,
                    totalCurrencyBalance: item.totalCurrencyBalance,
                    fiatBalance: item.totalCurrencyBalance,
                    chainId: chainIdToFind
                }
            }
        }
    }

    function stripTrailingZeros(strNumber) {
        if (!(typeof strNumber === "string")) {
            try {
                strNumber = strNumber.toString()
            } catch(e) {
                throw "[Utils.stripTrailingZeros] input parameter must be a string"
            }
        }
        return strNumber.replace(/(\.[0-9]*[1-9])0+$|\.0*$/,'$1')
    }

    function isHtml(text) {
        return (/<\/?[a-z][\s\S]*>/i.test(text))
    }

    // function to draw arrow
    function drawArrow(context, fromx, fromy, tox, toy, color, offset) {
        const fromX = fromx + 8
        const toX = tox - 8
        const dx = toX - fromX;
        const dy = toy - fromy;
        const headlen = 8; // length of head in pixels
        const angle = 0
        const radius = 4

        context.strokeStyle = color ? color : '#627EEA'

        // straight line
        if(dy === 0) {
            // draw circle
            context.setLineDash([20,0])
            context.beginPath()
            context.arc(fromX+radius, fromy, radius, 0, 360)
            context.stroke()

            // draw straightline
            context.setLineDash([3])
            context.beginPath()
            context.moveTo(fromX + 2*radius, fromy)
            context.lineTo(toX, toy)
            context.stroke()

            // draw arrow
            context.setLineDash([20,0])
            context.beginPath()
            context.moveTo(toX - headlen * Math.cos(angle - Math.PI / 4), toy - headlen * Math.sin(angle - Math.PI / 4))
            context.lineTo(toX, toy)
            context.lineTo(toX - headlen * Math.cos(angle + Math.PI / 4), toy - headlen * Math.sin(angle + Math.PI / 4))
            context.stroke()
        }
        // connecting between 2 different y positions
        else {
            // draw circle
            context.setLineDash([20,0])
            context.beginPath()
            context.arc(fromX+radius, fromy, radius, 0, 360)
            context.stroke()

            // draw bent line
            context.setLineDash([3])
            context.beginPath()
            context.moveTo(fromX + 2*radius, fromy)
            context.lineTo(fromX + dx / 2 - offset, fromy)
            context.lineTo(fromX + dx / 2 - offset, toy + (dy < 0 ? radius : -radius))
            context.stroke()

            // draw connecting circle
            context.setLineDash([20,0])
            context.beginPath()
            context.moveTo(fromX + dx / 2 + radius - offset, toy)
            context.arc(fromX + dx / 2 - offset, toy, radius, 0, 2*Math.PI,false)
            context.stroke()

            // draw straightline
            context.setLineDash([3])
            context.beginPath()
            context.moveTo(fromX + dx / 2 + 2*radius - offset, toy);
            context.lineTo(toX, toy)
            context.stroke()

            // draw arrow
            context.setLineDash([20,0])
            context.beginPath()
            context.moveTo(toX - headlen * Math.cos(angle - Math.PI / 6), toy - headlen * Math.sin(angle - Math.PI / 6))
            context.lineTo(toX, toy )
            context.lineTo(toX - headlen * Math.cos(angle + Math.PI / 6), toy - headlen * Math.sin(angle + Math.PI / 6))
            context.stroke()
        }
    }

    function linkifyAndXSS(inputText, linkAddressAndEnsName = false) {
        //URLs starting with http://, https://, ftp:// or status-app://
        var replacePattern1 = /(\b(https?|ftp|status-app):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;\(\)]*[-A-Z0-9+&@#\/%=~_|])/gim;
        var replacedText = inputText.replace(replacePattern1, "<a href='$1'>$1</a>");

        //URLs starting with "www." (without // before it, or it'd re-link the ones done above).
        var replacePattern2 = /(^|[^\/])(www\.[\S]+(\b|$))/gim;
        replacedText = replacedText.replace(replacePattern2, "$1<a href='http://$2'>$2</a>");

        if (linkAddressAndEnsName) {
            // Wallet address
            var replacePatternWalletAddress = /(^|[^\/])(0x[a-fA-F0-9]{40})/gim;
            replacedText = replacedText.replace(replacePatternWalletAddress, "$1<a class='eth-link' href='//send-via-personal-chat//$2'>$2</a>");

            // Ens Name
            var replacePatternENS = /\b[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*\.eth\b(?!\.\w)/g;
            replacedText = replacedText.replace(replacePatternENS, function(match) {
                return "<a class='eth-link' href='//send-via-personal-chat//" + match + "'>" + match + "</a>";
            });
        }

        return XSS.filterXSS(replacedText)
    }

    function filterXSS(inputText) {
        return XSS.filterXSS(inputText)
    }

    function getMessageWithStyle(palette, msg, hoveredLink = "", ethLinkDisabled = false) {
        const ethLinkColor = ethLinkDisabled ? palette.directColor1 : palette.primaryColor1
        const ethLinkHoverColor = ethLinkDisabled ? palette.baseColor1 : palette.primaryColor1
        const ethLinkHoverBackgroundColor = ethLinkDisabled ? palette.directColor8 : palette.primaryColor3
        return `<style type="text/css">` +
                    `img, a, del, code, blockquote { margin: 0; padding: 0; }` +
                    `code {` +
                        `font-family: ${Fonts.codeFont.family};` +
                        `font-weight: 400;` +
                        `font-size: 14;` +
                        `padding: 2px 4px;` +
                        `border-radius: 4px;` +
                        `background-color: ${palette.baseColor2};` +
                        `color: ${palette.directColor1};` +
                        `white-space: pre;` +
                    `}` +
                    `p {` +
                        `line-height: 22px;` +
                    `}` +
                    `a {` +
                        `color: ${palette.primaryColor1};` +
                    `}` +
                    `a.eth-link {` +
                        `color: ${ethLinkColor};` +
                    `}` +
                    // Simulated hover effect for eth-link via hoveredLink
                    (hoveredLink !== "" ?
                        `a[href="${hoveredLink}"].eth-link {` +
                            `color: ${ethLinkHoverColor};` +
                            `background-color: ${ethLinkHoverBackgroundColor};` +
                        `}` : ``) +
                    `a.mention {` +
                        `color: ${palette.mentionColor1};` +
                        `background-color: ${palette.mentionColor4};` +
                        `text-decoration: none;` +
                        `padding: 0px 2px;` +
                    `}` +
                    (hoveredLink !== "" ? `a.mention[href="${hoveredLink}"] { background-color: ${palette.mentionColor2}; }` : ``) +
                    (hoveredLink !== "" ? `a[href="${hoveredLink}"] { background-color: ${palette.primaryColor3}; }` : ``) +
                    `del {` +
                        `text-decoration: line-through;` +
                    `}` +
                    `.emoji {` +
                        `vertical-align: bottom;` +
                    `}` +
                    `span.isEdited {` +
                        `color: ${palette.baseColor1};` +
                        `margin-left: 5px` +
                    `}` +
                `</style>` +
                `${msg}`
    }

    function convertToSingleLine(text) {
        return text.replace(/<br\s*\/>/gm, " ")
    }

    function stripHtmlTags(text) {
        return text.replace(/<[^>]*>?/gm, '')
    }

    function elideText(text, leftCharsCount, rightCharsCount = leftCharsCount) {
        return text.substr(0, leftCharsCount) + "…" + text.substr(text.length - rightCharsCount)
    }

    function elideAndFormatWalletAddress(address) {
        return elideText(address, 6, 4).replace(
                    "0x", "0" + String.fromCodePoint(0x00D7))
    }

    function ensureVisible(flickable, rect) {
        const rectRight = rect.x + rect.width
        const rectBottom = rect.y + rect.height
        const flickableRight = flickable.contentX + flickable.width
        const flickableBottom = flickable.contentY + flickable.height

        if (flickable.contentX >= rect.x)
            flickable.contentX = rect.x
        else if (flickableRight <= rectRight)
            flickable.contentX = rectRight - flickable.width

        if (flickable.contentY >= rect.y)
            flickable.contentY = rect.y
        else if (flickableBottom <= rectBottom)
            flickable.contentY = rectBottom - flickable.height
    }

    function encodeUtf8(str){
        return unescape(encodeURIComponent(str));
    }

    function deviceIcon(deviceType) {
        const isMobileDevice = deviceType === "ios" || deviceType === "android"
        return isMobileDevice ? "mobile" : "desktop"
    }

    function stripHttpsAndwwwFromUrl(text) {
        return text.replace(/http(s)?(:)?(\/\/)?|(\/\/)?(www\.)?(\/)/gim, '')
    }

    /**
      - given a contiguous array of non repeating numbers from [0..totalCount-1]
      - @return an array of @p n random numbers, sorted in ascending order
      Example:
        const arr = [0, 1, 2, 3, 4, 5]
        const indexes = nSamples(3, 6) // pick 3 random numbers from an array of 6 elements [0..5]
        console.log(indexes) -> Array[0, 4, 5] // example output
      */
    function nSamples(n, totalCount) {
        if (n > totalCount) {
            console.error("'n' must be less than or equal to 'totalCount'")
            return
        }

        let set = new Set()
        while (set.size < n) {
            set.add(~~(Math.random() * totalCount))
        }
        return [...set].sort((a, b) => a - b)
    }

    function formatAccessibleName(defaultName, testId) {
        const content = (defaultName || "").toString().trim()
        const tid = (testId || "").toString().trim()
        
        if (!TestConfig.testMode || tid.length === 0) {
            return content
        }
        
        const tidSuffix = " [tid:" + tid + "]"
        
        return content.length > 0 ? (content + tidSuffix) : tidSuffix
    }
}
