pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property int browserSearchEngineNone: 0
    readonly property int browserSearchEngineDuckDuckGo: 1
    readonly property int browserSearchEngineQwant: 2
    readonly property int browserSearchEngineStartpage: 3
    readonly property int browserSearchEngineMojeek: 4
    readonly property int browserSearchEngineEcosia: 5
    readonly property int browserSearchEngineBing: 6
    readonly property int browserSearchEngineGoogle: 7
    readonly property int browserSearchEngineCustom: 8

    readonly property ListModel engines: ListModel {
        ListElement {
            engineId: 0  // browserSearchEngineNone
            name: qsTr("None")
            description: qsTr("valid URLs open directly; non-addresses won't be searched.")
            iconUrl: "search_engines/none"
            urlTemplate: ""
        }
        ListElement {
            engineId: 1  // browserSearchEngineDuckDuckGo
            name: "DuckDuckGo"
            description: ""
            iconUrl: "search_engines/duckduckgo"
            urlTemplate: "https://duckduckgo.com/?q=%1"
        }
        ListElement {
            engineId: 2  // browserSearchEngineQwant
            name: "Qwant"
            description: ""
            iconUrl: "search_engines/qwant"
            urlTemplate: "https://www.qwant.com/?q=%1"
        }
        ListElement {
            engineId: 3  // browserSearchEngineStartpage
            name: "Startpage"
            description: ""
            iconUrl: "search_engines/starpage"
            urlTemplate: "https://www.startpage.com/sp/search?q=%1"
        }
        ListElement {
            engineId: 4  // browserSearchEngineMojeek
            name: "Mojeek"
            description: ""
            iconUrl: "search_engines/mojeek"
            urlTemplate: "https://www.mojeek.com/search?q=%1"
        }
        ListElement {
            engineId: 5  // browserSearchEngineEcosia
            name: "Ecosia"
            description: ""
            iconUrl: "search_engines/ecosia"
            urlTemplate: "https://www.ecosia.org/search?q=%1"
        }
        ListElement {
            engineId: 6  // browserSearchEngineBing
            name: "Bing"
            description: ""
            iconUrl: "search_engines/bing"
            urlTemplate: "https://www.bing.com/search?q=%1"
        }
        ListElement {
            engineId: 7  // browserSearchEngineGoogle
            name: "Google"
            description: ""
            iconUrl: "search_engines/google"
            urlTemplate: "https://www.google.com/search?q=%1"
        }
        ListElement {
            engineId: 8  // browserSearchEngineCustom
            name: qsTr("Custom")
            description: qsTr("Plug in your own search engine that follows the OpenSearch URL format")
            iconUrl: "search_engines/custom"
            urlTemplate: ""
        }
    }

    function getEngineById(engineId) {
        for (let i = 0; i < engines.count; i++) {
            if (engines.get(i).engineId === engineId) {
                return engines.get(i)
            }
        }
        return null
    }

    function getEngineByIdOrDefault(engineId) {
        const engine = getEngineById(engineId)
        if (!engine) {
            console.warn("SearchEnginesConfig: Invalid engine ID", engineId, "- using DuckDuckGo as default")
            return getEngineById(browserSearchEngineDuckDuckGo)
        }
        return engine
    }

    function isValidEngineId(engineId) {
        return getEngineById(engineId) !== null
    }

    function getEngineName(engineId) {
        const engine = getEngineByIdOrDefault(engineId)
        return engine ? engine.name : qsTr("None")
    }

    function getEngineDescription(engineId) {
        const engine = getEngineByIdOrDefault(engineId)
        return engine ? engine.description : ""
    }

    function getEngineIcon(engineId = "") {
        const engine = getEngineByIdOrDefault(engineId)
        return engine ? engine.iconUrl : ""
    }

    function formatSearchUrl(engineId, query, customUrl) {
        const engine = getEngineByIdOrDefault(engineId)
        if (!engine) {
            return ""
        }
        
        // Custom: append query to the custom URL prefix
        if (engine.engineId === browserSearchEngineCustom) {
            if (!customUrl || customUrl === "") {
                console.warn("SearchEnginesConfig: Custom search engine selected but no URL configured")
                return ""
            }
            return customUrl + encodeURIComponent(query)
        }
        
        if (!engine.urlTemplate) {
            console.warn("SearchEnginesConfig: No URL template for engine:", engine.name)
            return ""
        }
        return engine.urlTemplate.replace("%1", encodeURIComponent(query))
    }
}

