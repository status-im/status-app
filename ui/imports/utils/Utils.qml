pragma Singleton

import QtQuick

import shared

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils

QtObject {
    function isDigit(value) {
        return /^\d$/.test(value);
    }

    function isHex(value) {
        return /^(-0x|0x)?[0-9a-fA-F]*$/i.test(value)
    }

    function startsWith0x(value) {
        return !!value && value.startsWith('0x')
    }

    function getCommunityIdFromFullChatId(fullChatId) {
        return fullChatId.substr(0, Constants.communityIdLength)
    }

    function getChannelUuidFromFullChatId(fullChatId) {
        return fullChatId.substr(Constants.communityIdLength, fullChatId.length)
    }

    function isValidETHNamePrefix(value) {
        return !(value.trim() === "" || value.endsWith(".") || value.indexOf("..") > -1)
    }

    function isAddress(value) {
        return startsWith0x(value) && isHex(value) && value.length === 42
    }

    function getChainsPrefix(address) {
        // matchAll is not supported by QML JS engine
        return address.match(/([a-zA-Z]{3,5}:)*/)[0].split(':').filter(e => !!e)
    }

    function isLikelyEnsName(text) {
        return text.startsWith("@") || !isLikelyAddress(text)
    }

    function isLikelyAddress(text) {
        return text.includes(":") || text.includes('0x')
    }

    function richColorText(text, color) {
        return "<font color=\"" + color + "\">" + text + "</font>"
    }

    function isPrivateKey(value) {
        return isHex(value) && ((startsWith0x(value) && value.length === 66) ||
                                (!startsWith0x(value) && value.length === 64))
    }

    function validLink(link) {
        if (link.length === 0) {
            return false
        }
        var regex = /[(http(s)?):\/\/(www\.)?a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)/
        return regex.test(link)
    }

    function getLinkStyle(link, hoveredLink, textColor) {
        return `<style type="text/css">` +
                `a {` +
                `color: ${textColor};` +
                `text-decoration: none;` +
                `}` +
                (hoveredLink !== "" ? `a[href="${hoveredLink}"] { text-decoration: underline; }` : "") +
                `</style>` +
                `<a href="${link}">${link}</a>`
    }

    function getStyledLink(linkText, linkUrl, hoveredLink, textColor, linkColor, underlineLink = true) {
        return `<style type="text/css">` +
                `a {` +
                `color: ${textColor};` +
                (underlineLink ? `text-decoration: underline;` : `text-decoration: none;`) +
                `}` +
                (hoveredLink === linkUrl ? `a[href="${linkUrl}"] { text-decoration: underline; color: ${linkColor} }` : "") +
                `</style>` +
                `<a href="${linkUrl}">${linkText}</a>`
    }

    function isMnemonic(value) {
        if(!value.match(/^([a-z\s]+)$/)){
            return false;
        }
        return seedPhraseValidWordCount(value);
    }

    function splitWords(mnemonic) {
        const trimmed = mnemonic.trim()
        if (trimmed === "")
            return []
        return trimmed.replace(/  +/g, " ").split(" ")
    }

    function compactAddress(addr, numberOfChars) {
        if(addr.length <= 5 + (numberOfChars * 2)){  //   5 represents these chars 0x...
            return addr;
        }
        return addr.substring(0, 2 + numberOfChars) + "..." + addr.substring(addr.length - numberOfChars);
    }

    function isOnlyEmoji(inputText) {
        var emoji_regex = /^(?:[\u2700-\u27bf]|(?:\ud83c[\udde6-\uddff]){2}|[\ud800-\udbff][\udc00-\udfff]|[\u0023-\u0039]\ufe0f?\u20e3|\u3299|\u3297|\u303d|\u3030|\u24c2|\ud83c[\udd70-\udd71]|\ud83c[\udd7e-\udd7f]|\ud83c\udd8e|\ud83c[\udd91-\udd9a]|\ud83c[\udde6-\uddff]|[\ud83c[\ude01-\ude02]|\ud83c\ude1a|\ud83c\ude2f|[\ud83c[\ude32-\ude3a]|[\ud83c[\ude50-\ude51]|\u203c|\u2049|[\u25aa-\u25ab]|\u25b6|\u25c0|[\u25fb-\u25fe]|\u00a9|\u00ae|\u2122|\u2139|\ud83c\udc04|[\u2600-\u26FF]|\u2b05|\u2b06|\u2b07|\u2b1b|\u2b1c|\u2b50|\u2b55|\u231a|\u231b|\u2328|\u23cf|[\u23e9-\u23f3]|[\u23f8-\u23fa]|\ud83c\udccf|\u2934|\u2935|[\u2190-\u21ff]|\s)+$/;
        return emoji_regex.test(inputText);
    }

    function isValidAddress(inputValue) {
        return inputValue !== "0x" && /^0x[a-fA-F0-9]{40}$/.test(inputValue)
    }

    function isValidEns(inputValue) {
        if (!inputValue) {
            return false
        }
        const isEmail = /(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])/.test(inputValue)
        const isDomain = /\b((?=[a-z0-9-]{1,63}\.)(xn--)?[a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,63}\b/.test(inputValue)
        return isEmail || isDomain || (inputValue.startsWith("@") && inputValue.length > 1)
    }

    /**
     * Removes trailing zeros from a string-representation of a number. Throws
     * if parameter is not a string
     */
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

    /**
     * Removes starting zeros from a string-representation of a number. Throws
     * if parameter is not a string
     */
    function stripStartingZeros(strNumber) {
        if (!(typeof strNumber === "string")) {
            try {
                strNumber = strNumber.toString()
            } catch(e) {
                throw "[Utils.stripStartingZeros] input parameter must be a string"
            }
        }
        return strNumber.replace(/^(0*)([0-9\.]+)/, "$2")
    }

    function setColorAlpha(color, alpha) {
        return Qt.hsla(color.hslHue, color.hslSaturation, color.hslLightness, alpha)
    }

    function isValidChannelName(channelName) {
        return (/^[a-z0-9\-]+$/.test(channelName))
    }

    function isURL(text) {
        return (/https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}(\.[a-zA-Z0-9()]{1,6})?\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)/.test(text))
    }

    function isURLWithOptionalProtocol(text) {
        return (/^(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)/.test(text))
    }

    function isHexColor(c) {
        return (/^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})$/i.test(c))
    }

    function isSpace(c) {
        return (/( |\t|\n|\r)/.test(c))
    }

    function getTick(wordCount) {
        return (wordCount === 12 || wordCount === 15 ||
                wordCount === 18 || wordCount === 21 || wordCount === 24)
                ? "✓ " : "";
    }

    function isValidNumberOfWords(wordCount) {
        return !!getTick(wordCount);
    }

    function countWords(text) {
        return splitWords(text).length
    }

    function seedPhraseValidWordCount(text) {
        return isValidNumberOfWords(countWords(text))
    }

    /**
     * Returns text in the format "✓ 12 words" for seed phrases input boxes
     */
    function seedPhraseWordCountText(text) {
        const wordCount = countWords(text);
        return getTick(wordCount) + qsTr("%n word(s)", "", wordCount)
    }

    function uuid() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 5)
    }

    function validatePasswords(item, firstPasswordField, repeatPasswordField) {
        switch (item) {
            case "first":
                if (firstPasswordField.text === "") {
                    return [false, qsTr("You need to enter a password")];
                } else if (firstPasswordField.text.length < Constants.minPasswordLength) {
                    return [false, qsTr("Password needs to be %n character(s) or more", "", Constants.minPasswordLength)];
                }
                return [true, ""];

            case "repeat":
                if (repeatPasswordField.text === "") {
                    return [false, qsTr("You need to repeat your password")];
                } else if (repeatPasswordField.text !== firstPasswordField.text) {
                    return [false, qsTr("Passwords don't match")];
                }
                return [true, ""];

            default:
                return [false, ""];
        }
    }

    function validatePINs(item, firstPINField, repeatPINField) {
        switch (item) {
            case "first":
                if (firstPINField.pinInput === "") {
                    return [false, qsTr("You need to enter a PIN")];
                } else if (!/^\d+$/.test(firstPINField.pinInput)) {
                    return [false, qsTr("The PIN must contain only digits")];
                } else if (firstPINField.pinInput.length != Constants.keycard.general.keycardPinLength) {
                    return [false, qsTr("The PIN must be exactly %n digit(s)", "", Constants.keycard.general.keycardPinLength)];
                }
                return [true, ""];

            case "repeat":
                if (repeatPINField.pinInput === "") {
                    return [false, qsTr("You need to repeat your PIN")];
                } else if (repeatPINField.pinInput !== firstPINField.pinInput) {
                    return [false, qsTr("PINs don't match")];
                }
                return [true, ""];

            default:
                return [false, ""];
        }
    }

    function getHostname(url) {
        const rgx = /\:\/\/(?:[a-zA-Z0-9\-]*\.{1,}){1,}[a-zA-Z0-9]*/i
        const matches = rgx.exec(url)
        if (!matches || !matches.length) {
            if (url.includes(Constants.deepLinkPrefix)) {
                return Constants.deepLinkPrefix
            }
            return  ""
        }
        return matches[0].substring(3)
    }

    function isStatusDeepLink(link) {
        return link.includes(Constants.deepLinkPrefix) || link.includes(Constants.externalStatusLink)
    }

    function removeGifUrls(message) {
        return message.replace(/(?:https?|ftp):\/\/[\n\S]*(\.gif)+/gm, '');
    }

    function isValidDragNDropImage(url) {
        return String(url).startsWith(Constants.dataImagePrefix) || UrlUtils.isValidImageUrl(url)
    }

    function isFilesizeValid(img) {
        if (String(img).startsWith(Constants.dataImagePrefix)) {
            return img.length < Constants.maxImgSizeBytes
        }
        const size = UrlUtils.getFileSize(img)
        return size <= Constants.maxImgSizeBytes
    }

    function deduplicate(array) {
        return Array.from(new Set(array))
    }

    function hasUpperCaseLetter(str) {
        return (/[A-Z]/.test(str))
    }

    function convertSpacesToDashes(str)
    {
        return str.replace(/ /g, "-")
    }

    /* Validation section start */

    enum Validate {
        NoEmpty = 0x01,
        TextLength = 0x02,
        TextHexColor = 0x04,
        TextLowercaseLettersNumberAndDashes = 0x08
    }

    function validateAndReturnError(str, validation, fieldName = "field", limit = 0)
    {
        let errMsg = ""

        if(validation & Utils.Validate.NoEmpty && str === "") {
            errMsg = qsTr("You need to enter a %1").arg(fieldName)
        }

        if(validation & Utils.Validate.TextLength && str.length > limit) {
            errMsg = qsTr("The %1 cannot exceed %n character(s)", "", limit).arg(fieldName)
        }

        if(validation & Utils.Validate.TextHexColor && !isHexColor(str)) {
            errMsg = qsTr("Must be an hexadecimal color (eg: #4360DF)")
        }

        if(validation & Utils.Validate.TextLowercaseLettersNumberAndDashes && !isValidChannelName(str)) {
            errMsg = qsTr("Use only lowercase letters (a to z), numbers & dashes (-). Do not use chat keys.")
        }

        return errMsg
    }

    function getErrorMessage(errors, fieldName) {
        if (errors) {
            if (errors.minLength) {
                return errors.minLength.min === 1 ?
                    qsTr("You need to enter a %1").arg(fieldName) :
                    qsTr("Value has to be at least %n character(s) long", "", errors.minLength.min)
            }
        }
        return ""
    }

    /* Validation section end */

    function colorForColorId(palette, colorId)  {
        if (colorId < 0 || colorId >= palette.userCustomizationColors.length) {
            console.warn("Utils.colorForColorId : colorId is out of bounds")
            return StatusColors.blue
        }
        return palette.userCustomizationColors[colorId]
    }

    function getChatKeyFromShareLink(link) {
        let index = link.lastIndexOf("/u/")
        if (index === -1) {
            return link
        }
        return link.substring(index + 3)
    }

    function getElidedPk(publicKey) {
        if (publicKey === "") {
            return ""
        }
        return StatusQUtils.Utils.elideText(publicKey, 3, 6)
    }

    function getElidedCommunityPK(publicKey) {
        if (publicKey === "") {
            return ""
        }
        return StatusQUtils.Utils.elideText(publicKey, 16)
    }

    function elideIfTooLong(str, maxLength) {
        return (str.length > maxLength) ? str.substr(0, maxLength-4) + '...' : str;
    }

    function isInvalidPasswordMessage(msg) {
        return (
            msg.includes("could not decrypt key with given password") ||
            msg.includes("invalid password")
        );
    }

    function isInvalidPrivateKey(msg) {
        return msg.includes("invalid private key");
    }

    function isInvalidPath(msg) {
        return msg.includes(Constants.wrongDerivationPathError)
    }

    function accountAlreadyExistsError(msg) {
        return msg.includes(Constants.existingAccountError)
    }

    // See also: backend/interpret/cropped_image.nim
    function getImageAndCropInfoJson(imgPath, cropRect) {
        return JSON.stringify({imagePath: String(imgPath).replace("file://", ""), cropRect: cropRect})
    }

    // handle translations for section names coming from app_sections_config.nim
    function translatedSectionName(sectionType, fallback, additionalTextFunction) {
        if (additionalTextFunction === undefined) {
            additionalTextFunction = function() { return "" }
        }

        switch(sectionType) {
        case Constants.appSection.chat:
            return qsTr("Messages")
        case Constants.appSection.wallet:
            return qsTr("Wallet")
        case Constants.appSection.browser:
            return qsTr("Browser")
        case Constants.appSection.profile:
            return qsTr("Settings")
        case Constants.appSection.node:
            return qsTr("Node Management")
        case Constants.appSection.communitiesPortal:
            return qsTr("Discover Communities")
        case Constants.appSection.loadingSection:
            return qsTr("Chat section loading...")
        case Constants.appSection.swap:
            return qsTr("Swap")
        case Constants.appSection.market:
            return qsTr("Market")
        case Constants.appSection.community:
            return qsTr("Community")
        case Constants.appSection.dApp:
            return qsTr("dApp")
        case Constants.appSection.homePage:
            return "%1 (%2)".arg(qsTr("Home Page")).arg(additionalTextFunction(sectionType))
        case Constants.appSection.activityCenter:
            return qsTr("Activity Center")
        default:
            return fallback
        }
    }

    function appTranslation(key) {
        switch(key) {
        case Constants.appTranslatableConstants.loginAccountsListAddNewUser:
            return qsTr("Add new user")
        case Constants.appTranslatableConstants.loginAccountsListAddExistingUser:
            return qsTr("Add existing Status user")
        case Constants.appTranslatableConstants.loginAccountsListLostKeycard:
            return qsTr("Lost Keycard")
        case Constants.appTranslatableConstants.addAccountLabelNewWatchOnlyAccount:
            return qsTr("New watched address")
        case Constants.appTranslatableConstants.addAccountLabelWatchOnlyAccount:
            return qsTr("Watched address")
        case Constants.appTranslatableConstants.addAccountLabelExisting:
            return qsTr("Existing")
        case Constants.appTranslatableConstants.addAccountLabelImportNew:
            return qsTr("Import new")
        case Constants.appTranslatableConstants.addAccountLabelOptionAddNewMasterKey:
            return qsTr("Add new master key")
        case Constants.appTranslatableConstants.addAccountLabelOptionAddWatchOnlyAcc:
            return qsTr("Add watched address")
        }

        // special handling because on an index attached to the constant
        if (key.startsWith(Constants.appTranslatableConstants.keycardAccountNameOfUnknownWalletAccount)) {
            let num = key.substring(Constants.appTranslatableConstants.keycardAccountNameOfUnknownWalletAccount.length)
            return "%1%2".arg(qsTr("acc", "short for account")).arg(num) //short name of an unknown (removed) wallet account
        }

        return key
    }

    function dropUserLinkPrefix(text) {
        if (text.startsWith(Constants.userLinkPrefix))
            text = text.slice(Constants.userLinkPrefix.length)
        return text
    }

    function dropCommunityLinkPrefix(text) {
        if (text.startsWith(Constants.communityLinkPrefix))
            text = text.slice(Constants.communityLinkPrefix.length)
        return text
    }

    function getHoveredColor(palette, colorId) {
        switch(colorId.toString().toUpperCase()) {
        case Constants.walletAccountColors.primary.toUpperCase():
            return palette.customisationColors.blue
        case Constants.walletAccountColors.purple.toUpperCase():
            return palette.customisationColors.purple
        case Constants.walletAccountColors.orange.toUpperCase():
            return palette.customisationColors.orange
        case Constants.walletAccountColors.army.toUpperCase():
            return palette.customisationColors.army
        case Constants.walletAccountColors.turquoise.toUpperCase():
            return palette.customisationColors.turquoise
        case Constants.walletAccountColors.sky.toUpperCase():
            return palette.customisationColors.sky
        case Constants.walletAccountColors.yellow.toUpperCase():
            return palette.customisationColors.yellow
        case Constants.walletAccountColors.pink.toUpperCase():
            return palette.customisationColors.pink
        case Constants.walletAccountColors.copper.toUpperCase():
            return palette.customisationColors.copper
        case Constants.walletAccountColors.camel.toUpperCase():
            return palette.customisationColors.camel
        case Constants.walletAccountColors.magenta.toUpperCase():
            return palette.customisationColors.magenta
        case Constants.walletAccountColors.yinYang.toUpperCase():
            return palette.name === Constants.lightThemeName ? StatusColors.blackHovered: StatusColors.grey4 // FIXME introduce symbolic color names
        case Constants.walletAccountColors.undefinedAccount.toUpperCase():
            return palette.baseColor1
        default:
            return getColorForId(palette, colorId)
        }
    }

    function getIdForColor(palette, color){
        let c = color.toString().toUpperCase()
        switch(c) {
        case palette.customisationColors.blue.toString().toUpperCase():
            return Constants.walletAccountColors.primary
        case palette.customisationColors.purple.toString().toUpperCase():
            return Constants.walletAccountColors.purple
        case palette.customisationColors.orange.toString().toUpperCase():
            return Constants.walletAccountColors.orange
        case palette.customisationColors.army.toString().toUpperCase():
            return Constants.walletAccountColors.army
        case palette.customisationColors.turquoise.toString().toUpperCase():
            return Constants.walletAccountColors.turquoise
        case palette.customisationColors.sky.toString().toUpperCase():
            return Constants.walletAccountColors.sky
        case palette.customisationColors.yellow.toString().toUpperCase():
            return Constants.walletAccountColors.yellow
        case palette.customisationColors.pink.toString().toUpperCase():
            return Constants.walletAccountColors.pink
        case palette.customisationColors.copper.toString().toUpperCase():
            return Constants.walletAccountColors.copper
        case palette.customisationColors.camel.toString().toUpperCase():
            return Constants.walletAccountColors.camel
        case palette.customisationColors.magenta.toString().toUpperCase():
            return Constants.walletAccountColors.magenta
        case palette.customisationColors.yinYang.toString().toUpperCase():
            return Constants.walletAccountColors.yinYang
        case palette.baseColor1.toString().toUpperCase():
            return Constants.walletAccountColors.undefinedAccount
        default:
            return Constants.walletAccountColors.primary
        }
    }

    function getColorForId(palette, colorId) {
        if(colorId) {
            switch(colorId.toUpperCase()) {
            case Constants.walletAccountColors.primary.toUpperCase():
                return palette.customisationColors.blue
            case Constants.walletAccountColors.purple.toUpperCase():
                return palette.customisationColors.purple
            case Constants.walletAccountColors.orange.toUpperCase():
                return palette.customisationColors.orange
            case  Constants.walletAccountColors.army.toUpperCase():
                return palette.customisationColors.army
            case  Constants.walletAccountColors.turquoise.toUpperCase():
                return palette.customisationColors.turquoise
            case  Constants.walletAccountColors.sky.toUpperCase():
                return palette.customisationColors.sky
            case  Constants.walletAccountColors.yellow.toUpperCase():
                return palette.customisationColors.yellow
            case  Constants.walletAccountColors.pink.toUpperCase():
                return palette.customisationColors.pink
            case  Constants.walletAccountColors.copper.toUpperCase():
                return palette.customisationColors.copper
            case  Constants.walletAccountColors.camel.toUpperCase():
                return palette.customisationColors.camel
            case  Constants.walletAccountColors.magenta.toUpperCase():
                return palette.customisationColors.magenta
            case  Constants.walletAccountColors.yinYang.toUpperCase():
                return palette.customisationColors.yinYang
            case  Constants.walletAccountColors.undefinedAccount.toUpperCase():
                return palette.baseColor1
            }
        }
        return palette.customisationColors.blue
    }

    function getColorIndexForId(palette, colorId) {
        let color = getColorForId(palette, colorId)
        for (let i = 0; i < palette.customisationColorsArray.length; i++) {
            if(palette.customisationColorsArray[i] === color) {
                return i
            }
        }
        return 0
    }

    function getContrastingColor(palette, color) {
        const hexcolor = color.toString()
        const r = parseInt(hexcolor.substring(1,3), 16);
        const g = parseInt(hexcolor.substring(3,5), 16);
        const b = parseInt(hexcolor.substring(5,7), 16);
        const yiq = ((r*299)+(g*587)+(b*114))/1000;
        return (yiq >= 128) ? palette.black : palette.white;
    }

    function getPathForDisplay(path) {
        return path.split("/").join(" / ")
    }

    function getKeypairLocationColor(palette, keypair) {
        return !keypair ||
                keypair.migratedToKeycard ||
                keypair.operability === Constants.keypair.operability.fullyOperable ||
                keypair.operability === Constants.keypair.operability.partiallyOperable?
                    palette.baseColor1 :
                    palette.warningColor1
    }

    function getExplorerDomain(networkShortName, testnetMode) {
        let link = Constants.networkExplorerLinks.etherscan
        if (networkShortName === Constants.networkShortChainNames.mainnet) {
            if (testnetMode) {
                link = Constants.networkExplorerLinks.sepoliaEtherscan
            }
        }
        if (networkShortName === Constants.networkShortChainNames.arbitrum) {
            link = Constants.networkExplorerLinks.arbiscan
            if (testnetMode) {
                link = Constants.networkExplorerLinks.sepoliaArbiscan
            }
        } else if (networkShortName === Constants.networkShortChainNames.optimism) {
            link = Constants.networkExplorerLinks.optimism
            if (testnetMode) {
                link = Constants.networkExplorerLinks.sepoliaOptimism
            }
        } else if (networkShortName === Constants.networkShortChainNames.base) {
            link = Constants.networkExplorerLinks.base
            if (testnetMode) {
                link = Constants.networkExplorerLinks.sepoliaBase
            }
        } else if (networkShortName === Constants.networkShortChainNames.status) {
            link = Constants.networkExplorerLinks.status
            if (testnetMode) {
                link = Constants.networkExplorerLinks.sepoliaStatus
            }
        } else if (networkShortName === Constants.networkShortChainNames.binanceSmartChain) {
            link = Constants.networkExplorerLinks.binanceSmartChain
            if (testnetMode) {
                link = Constants.networkExplorerLinks.testnetBinanceSmartChain
            }
        }
        return link
    }

    function getEtherscanUrl(networkShortName, testnetMode, addressOrTx, isAddressNotTx)  {
        const type = isAddressNotTx
            ? Constants.networkExplorerLinks.addressPath
            : Constants.networkExplorerLinks.txPath
        let link = getExplorerDomain(networkShortName, testnetMode)

        return "%1/%2/%3".arg(link).arg(type).arg(addressOrTx)
    }

    // Etherscan URL for an address
    function getUrlForAddressOnNetwork(networkShortName, testnetMode, address)  {
        return getEtherscanUrl(networkShortName, testnetMode, address, true /* is address */)
    }

    // Etherscan URL for a transaction
    function getUrlForTxOnNetwork(networkShortName, testnetMode, tx)  {
        return getEtherscanUrl(networkShortName, testnetMode, tx, false /* is TX */)
    }

    // Get Chain Explorer name
    function getChainExplorerName(networkShortName) {
        if (networkShortName === Constants.networkShortChainNames.arbitrum) {
            return qsTr("Arbiscan")
        }
        if (networkShortName === Constants.networkShortChainNames.optimism) {
            return qsTr("Optimistic")
        }
        if (networkShortName === Constants.networkShortChainNames.base) {
            return qsTr("BaseScan")
        }
        if (networkShortName === Constants.networkShortChainNames.status) {
            return qsTr("Status Explorer")
        }
        if (networkShortName === Constants.networkShortChainNames.binanceSmartChain) {
            return qsTr("BscScan")
        }
        return qsTr("Etherscan")
    }

    // Get ShortName for ChainID
    function getNetworkShortName(chainID) {
        switch (chainID) {
            case Constants.chains.mainnetChainId:
            case Constants.chains.sepoliaChainId:
                return Constants.networkShortChainNames.mainnet
            case Constants.chains.arbitrumChainId:
            case Constants.chains.arbitrumSepoliaChainId:
                return Constants.networkShortChainNames.arbitrum
            case Constants.chains.optimismChainId:
            case Constants.chains.optimismSepoliaChainId:
                return Constants.networkShortChainNames.optimism
            case Constants.chains.baseChainId:
            case Constants.chains.baseSepoliaChainId:
                return Constants.networkShortChainNames.base
            case Constants.chains.statusNetworkChainId:
            case Constants.chains.statusNetworkSepoliaChainId:
                return Constants.networkShortChainNames.status
            case Constants.chains.binanceSmartChainMainnetChainId:
            case Constants.chains.binanceSmartChainTestnetChainId:
                return Constants.networkShortChainNames.binanceSmartChain
        }
        return ""
    }

    // Get Network name for ChainID
    function getNetworkName(chainID) {
        switch (chainID) {
            case Constants.chains.mainnetChainId:
                return Constants.networkNames.mainnet
            case Constants.chains.sepoliaChainId:
                return Constants.networkNames.sepolia
            case Constants.chains.arbitrumChainId:
                return Constants.networkNames.arbitrum
            case Constants.chains.arbitrumSepoliaChainId:
                return Constants.networkNames.sepoliaArbitrum
            case Constants.chains.optimismChainId:
                return Constants.networkNames.optimism
            case Constants.chains.optimismSepoliaChainId:
                return Constants.networkNames.sepoliaOptimism
            case Constants.chains.baseChainId:
                return Constants.networkNames.base
            case Constants.chains.baseSepoliaChainId:
                return Constants.networkNames.sepoliaBase
            case Constants.chains.statusNetworkChainId:
                return Constants.networkNames.status
            case Constants.chains.statusNetworkSepoliaChainId:
                return Constants.networkNames.sepoliaStatus
            case Constants.chains.binanceSmartChainMainnetChainId:
                return Constants.networkNames.binanceSmartChain
            case Constants.chains.binanceSmartChainTestnetChainId:
                return Constants.networkNames.testnetBinanceSmartChain
        }
    }

    // Is given ChainID a testnet
    function isChainIDTestnet(chainID) {
        switch (+chainID) {
            case Constants.chains.mainnetChainId:
            case Constants.chains.arbitrumChainId:
            case Constants.chains.optimismChainId:
            case Constants.chains.baseChainId:
            case Constants.chains.binanceSmartChainMainnetChainId:
                return false
        }
        return true
    }

    function isL1Chain(chainID) {
        switch (+chainID) {
            case Constants.chains.mainnetChainId:
            case Constants.chains.sepoliaChainId:
            case Constants.chains.binanceSmartChainMainnetChainId:
            case Constants.chains.binanceSmartChainTestnetChainId:
                return true
        }
        return false
    }

    function getNativeTokenGroupKey(chainId) {
        switch (chainId) {
            case Constants.chains.binanceSmartChainMainnetChainId:
            case Constants.chains.binanceSmartChainTestnetChainId:
                return Constants.bnbGroupKey
            default:
                return Constants.ethGroupKey
        }
    }

    // Get NativeTokenSymbol for ChainID
    function getNativeTokenSymbol(chainID) {
        switch (+chainID) {
            case Constants.chains.binanceSmartChainMainnetChainId:
            case Constants.chains.binanceSmartChainTestnetChainId:
                return Constants.bnbToken
            default:
                return Constants.ethToken
        }
    }

    // Returns gas token (that facilitates fee representation in locale) for chain.
    function getNativeGasTokenSymbol(chainID) {
        // Gas for all supported native tokens (currently ETH and BNB) are calculated in GWEI.
        return Constants.gweiToken
    }

    function getNativeTokenDecimals(chainID) {
        let decimals = Constants.rawDecimals[getNativeTokenSymbol(chainID)]
        if (!decimals) {
            // Default to eth
            decimals = Constants.rawDecimals[Constants.ethToken]
        }
        return decimals
    }

    function getNativeTokenGasDecimals(chainID) {
        let decimals = Constants.gasTokenDecimals[getNativeTokenSymbol(chainID)]
        if (!decimals) {
            // Default to eth
            decimals = Constants.gasTokenDecimals[Constants.ethToken]
        }
        return decimals
    }

    // Convert decimal value to raw (e.g. ETH to Wei)
    function nativeTokenDecimalToRaw(chainID, value) {
        const decimals = getNativeTokenDecimals(chainID)
        return StatusQUtils.AmountsArithmetic.times(StatusQUtils.AmountsArithmetic.fromString(value),
                                       StatusQUtils.AmountsArithmetic.fromNumber(1, decimals))
    }

    // Convert raw value to decimal (e.g. Wei to ETH)
    function nativeTokenRawToDecimal(chainID, value) {
        const decimals = getNativeTokenDecimals(chainID)
        return StatusQUtils.AmountsArithmetic.div(StatusQUtils.AmountsArithmetic.fromString(value),
                                      StatusQUtils.AmountsArithmetic.fromNumber(1, decimals))
    }

    // Convert gas value to decimal (e.g. GWei to ETH)
    function nativeTokenGasToDecimal(chainID, value) {
        const decimals = getNativeTokenGasDecimals(chainID)
        return StatusQUtils.AmountsArithmetic.div(StatusQUtils.AmountsArithmetic.fromString(value),
                                      StatusQUtils.AmountsArithmetic.fromNumber(1, decimals))
    }

    // Convert decimal value to gas (e.g. ETH to GWei)
    function nativeTokenDecimalToGas(chainID, value) {
        const decimals = getNativeTokenGasDecimals(chainID)
        return StatusQUtils.AmountsArithmetic.times(StatusQUtils.AmountsArithmetic.fromString(value),
                                       StatusQUtils.AmountsArithmetic.fromNumber(1, decimals))
    }

    // Convert raw value to gas (e.g. Wei to GWei)
    function nativeTokenRawToGas(chainID, value) {
        const rawDecimals = getNativeTokenDecimals(chainID)
        const gasDecimals = getNativeTokenGasDecimals(chainID)
        return StatusQUtils.AmountsArithmetic.div(StatusQUtils.AmountsArithmetic.fromString(value),
                                       StatusQUtils.AmountsArithmetic.fromNumber(1, rawDecimals - gasDecimals))
    }

    // Convert gas value to raw (e.g. GWei to Wei)
    function nativeTokenGasToRaw(chainID, value) {
        const rawDecimals = getNativeTokenDecimals(chainID)
        const gasDecimals = getNativeTokenGasDecimals(chainID)
        return StatusQUtils.AmountsArithmetic.times(StatusQUtils.AmountsArithmetic.fromString(value),
                                       StatusQUtils.AmountsArithmetic.fromNumber(1, rawDecimals - gasDecimals))
    }

    function calculateGasCost(chainID, gasPriceInGasUnit, gasAmount) {
        let rawGasPrice = nativeTokenGasToRaw(chainID, gasPriceInGasUnit)
        rawGasPrice = StatusQUtils.AmountsArithmetic.times(rawGasPrice, StatusQUtils.AmountsArithmetic.fromNumber(gasAmount))
        return nativeTokenRawToDecimal(chainID, rawGasPrice)
    }
    
    // TODO: https://github.com/status-im/status-desktop/issues/15329
    // Get DApp data from the backend
    function getDappDetails(chainId, contractAddress) {
        switch (contractAddress) {
            case Constants.swap.paraswapV5ApproveContractAddress:
            case Constants.swap.paraswapV5SwapContractAddress:
                return {
                    "icon": Theme.png("swap/%1".arg(Constants.swap.paraswapIcon)),
                    "url": Constants.swap.paraswapHostname,
                    "name": Constants.swap.paraswapName,
                    "approvalContractAddress": Constants.swap.paraswapV5ApproveContractAddress,
                    "swapContractAddress": Constants.swap.paraswapV5SwapContractAddress,
                }
            case Constants.swap.paraswapV6_2ContractAddress:
                return {
                    "icon": Theme.png("swap/%1".arg(Constants.swap.paraswapIcon)),
                    "url": Constants.swap.paraswapUrl,
                    "name": Constants.swap.paraswapName,
                    "approvalContractAddress": Constants.swap.paraswapV6_2ContractAddress,
                    "swapContractAddress": Constants.swap.paraswapV6_2ContractAddress,
                }
        }
        return undefined
    }

    // Leave this function at the bottom of the file as QT Creator messes up the code color after this
    function isPunct(c) {
        return /(!|\@|#|\$|%|\^|&|\*|\(|\)|\+|\||-|=|\\|{|}|[|]|"|;|'|<|>|\?|,|\.|\/)/.test(c)
    }

    function getUrlStatus(url) {
        // TODO: Analyse and implement
        // #15331
        return true
    }

    function toBase64(buffer) {
        const base64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        const bufferView = new Uint8Array(buffer);
        let result = "";
        let i;

        for (i = 0; i < bufferView.length - 2; i += 3) {
            const chunk = (bufferView[i] << 16) | (bufferView[i + 1] << 8) | bufferView[i + 2];
            result += base64Chars[(chunk >> 18) & 0x3F] +
                      base64Chars[(chunk >> 12) & 0x3F] +
                      base64Chars[(chunk >> 6) & 0x3F] +
                      base64Chars[chunk & 0x3F];
        }

        if (bufferView.length % 3 === 1) {
            const chunk = bufferView[i] << 16;
            result += base64Chars[(chunk >> 18) & 0x3F] +
                      base64Chars[(chunk >> 12) & 0x3F] +
                      "==";
        } else if (bufferView.length % 3 === 2) {
            const chunk = (bufferView[i] << 16) | (bufferView[i + 1] << 8);
            result += base64Chars[(chunk >> 18) & 0x3F] +
                      base64Chars[(chunk >> 12) & 0x3F] +
                      base64Chars[(chunk >> 6) & 0x3F] +
                      "=";
        }
        return result;
    }

    function fetchImageBase64(url, callback) {
        let xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.responseType = "arraybuffer";
        xhr.onload = function() {
            if (xhr.status === 200) {
                const base64Image = toBase64(xhr.response);
                const mimeType = xhr.getResponseHeader("Content-Type") || "image/png";
                callback(`data:${mimeType};base64,${base64Image}`);
            } else {
                callback("");
            }
        }
        xhr.send();
    }

    function getProfileType(isMe, isBridgedAccount, isBlocked) {
        if (isMe)
            return Constants.profileType.self
        if (isBridgedAccount)
            return Constants.profileType.bridged

        return isBlocked ? Constants.profileType.blocked
                         : Constants.profileType.regular
    }

    function getContactType(contactRequestState, isContact) {
        switch (contactRequestState) {
            case Constants.ContactRequestState.Received:
                return Constants.contactType.contactRequestReceived
            case Constants.ContactRequestState.Sent:
                return Constants.contactType.contactRequestSent
        }

        return isContact ? Constants.contactType.contact
                         : Constants.contactType.nonContact
    }

    // BACKEND DEPENDENT PART
    //
    // Methods and properties below are intended to be refactored in various
    // ways to finally make that singleton fully stateless and backend-independent.

    property var mainModuleInst: typeof mainModule !== "undefined" ? mainModule : null
    property var sharedUrlsModuleInst: typeof  sharedUrlsModule !== "undefined" ? sharedUrlsModule : null
    property var globalUtilsInst: typeof globalUtils !== "undefined" ? globalUtils : null
    property var communitiesModuleInst: typeof communitiesModule !== "undefined" ? communitiesModule : null

    function isChatKey(value) {
        return (startsWith0x(value) && isHex(value) && value.length === 132) || globalUtilsInst.isCompressedPubKey(value)
    }

    function getContactDetailsAsJson(publicKey, getVerificationRequest=true, getOnlineStatus=false, includeDetails=false) {
        const defaultValue = {
            icon: "",
            isCurrentUser: "",
            colorId: "",
            displayName: "",
            publicKey: publicKey,
            compressedPubKey: "",
            name: "",
            ensVerified: false,
            alias: "",
            lastUpdated: 0,
            lastUpdatedLocally: 0,
            localNickname: "",
            thumbnailImage: "",
            largeImage: "",
            isContact: false,
            isBlocked: false,
            isContactRequestReceived: false,
            isContactRequestSent: false,
            usesDefaultName: false,
            removed: false,
            trustStatus: Constants.trustStatus.unknown,
            contactRequestState: Constants.ContactRequestState.None,
            socialLinks: [],
            bio: "",
            onlineStatus: Constants.onlineStatus.inactive
        }

        if (!mainModuleInst || !publicKey)
            return defaultValue

        const jsonObj = mainModuleInst.getContactDetailsAsJson(publicKey, getVerificationRequest, getOnlineStatus, includeDetails)

        try {
            return JSON.parse(jsonObj)
        }
        catch (e) {
            // This log is available only in debug mode, if it's annoying we can remove it
            console.warn("error parsing contact details for public key: ", publicKey, " error: ", e.message)
            return defaultValue
        }
    }

    function isEnsVerified(publicKey) {
        if (publicKey === "" || !isChatKey(publicKey) )
            return false
        if (!mainModuleInst)
            return false
        return mainModuleInst.isEnsVerified(publicKey)
    }

    function colorIdForPubkey(publicKey) {
        if (publicKey === "" || !isChatKey(publicKey)) {
            return 0
        }
        return globalUtilsInst.getColorId(publicKey)
    }

    function colorForPubkey(palette, publicKey) {
        const pubKeyColorId = colorIdForPubkey(publicKey)
        return colorForColorId(palette, pubKeyColorId)
    }

    function getCommunityShareLink(communityId) {
        if (communityId === "") {
            return ""
        }

        return communitiesModuleInst.shareCommunityUrlWithData(communityId)
    }

    function getCommunityChannelShareLink(communityId, channelId) {
        if (communityId === "" || channelId === "")
            return ""
        return communitiesModuleInst.shareCommunityChannelUrlWithData(communityId, channelId)
    }

    function getCommunityChannelShareLinkWithChatId(chatId) {
        const communityId = getCommunityIdFromFullChatId(chatId)
        const channelId = getChannelUuidFromFullChatId(chatId)
        return getCommunityChannelShareLink(communityId, channelId)
    }

    function getCommunityDataFromSharedLink(link: string) {
        const communityDataString = sharedUrlsModuleInst.parseCommunitySharedUrl(link)
        try {
            return JSON.parse(communityDataString)
        } catch (e) {
            console.warn("Error while parsing community data from url:", e.message)
            return null
        }
    }

    // TODO: remove when getElidedCompressedPk moved to utilsStore
    function _getCompressedPk(publicKey) {
        if (publicKey === "") {
            return ""
        }
        if (!isChatKey(publicKey))
            return publicKey
        return globalUtilsInst.getCompressedPk(publicKey)
    }

    function getElidedCompressedPk(publicKey) {
        if (publicKey === "") {
            return ""
        }
        let compressedPk = _getCompressedPk(publicKey)
        return getElidedPk(compressedPk)
    }

    function parseContactUrl(link) {
        let index = link.lastIndexOf("/u/")

        if (index === -1) {
            index = link.lastIndexOf("/u#")
        }

        if (index === -1)
            return null

        const contactDataString = sharedUrlsModuleInst.parseContactSharedUrl(link)
        try {
            return JSON.parse(contactDataString)
        } catch (e) {
            return null
        }
    }

    function getKeypairLocation(keypair, fromAccountDetailsView) {
        if (!keypair || keypair.pairType === Constants.keypair.type.watchOnly) {
            return ""
        }

        let profileTitle = ""
        if (keypair.pairType === Constants.keypair.type.profile) {
            profileTitle = Utils.getElidedCompressedPk(keypair.pubKey) + Constants.settingsSection.dotSepString
        }
        if (keypair.migratedToKeycard) {
            return profileTitle + qsTr("On Keycard")
        }
        if (keypair.operability === Constants.keypair.operability.fullyOperable ||
                keypair.operability === Constants.keypair.operability.partiallyOperable) {
            return profileTitle + qsTr("On device")
        }
        if (keypair.operability === Constants.keypair.operability.nonOperable) {
            if (fromAccountDetailsView) {
                return qsTr("Requires import")
            } else if (keypair.syncedFrom === Constants.keypair.syncedFrom.backup) {
                if (keypair.pairType === Constants.keypair.type.seedImport ||
                        keypair.pairType === Constants.keypair.type.privateKeyImport) {
                    return qsTr("Restored from backup. Import key pair to use derived accounts.")
                }
            }
            return qsTr("Import key pair to use derived accounts")
        }

        return ""
    }

    function objectTypeName(item) {
        let typeName = item.toString()

        if (typeName.startsWith("QQuick"))
            typeName = typeName.substring(6)

        const underscoreIndex = typeName.indexOf("_")

        if (underscoreIndex !== -1)
            return typeName.substring(0, underscoreIndex)

        const bracketIndex = typeName.indexOf("(")

        if (bracketIndex !== -1)
            return typeName.substring(0, bracketIndex)

        return typeName
    }

    function getEnumerationString(list, finalSeparator) {
        let result = ""
        for (let i = 0; i < list.length; i++) {
            if (i == 0) {
                result += list[i]
            } else if (i == list.length - 1) {
                result += " %1 %2".arg(finalSeparator).arg(list[i])
            } else {
                result += ", %1".arg(list[i])
            }
        }
        return result
    }

    function buildTokenKey(chainId, address) {
        return "%1%2%3".arg(chainId).arg(Constants.tokenKeyDelimiter).arg(address.toLowerCase())
    }
}
