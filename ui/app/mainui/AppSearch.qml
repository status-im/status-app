import QtQuick

import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Popups

Item {
    id: root

    required property var locationMenuModel
    required property var resultModel
    required property bool searchInProgress
    required property var setSearchLocationFn
    required property var prepareLocationMenuModelFn
    required property var getSearchLocationObjectFn
    required property var isChatKeyFn
    required property var openProfilePopupFn

    readonly property var searchMessagesDebounced: Backpressure.debounce(searchPopup, 400, function () {
        if (searchPopup.searchText === "")
            return

        root.searchMessages(searchPopup.searchText)
    })
    property alias opened: searchPopup.opened

    signal closed()
    signal searchMessages(string searchTerm)
    signal resultItemClicked(string itemId)

    function clearSearchResults() {
        root.searchMessages("")
    }

    function openSearchPopup(){
        searchPopup.open()
    }

    function closeSearchPopup(){
        searchPopup.close()
    }

    Connections {
        target: root.locationMenuModel
        function onModelAboutToBeReset() {
             while (searchPopupMenu.takeItem(searchPopupMenu.numDefaultItems)) {
                // Delete the item right after the default items
                // If takeItem returns null, it means there was nothing to remove
            }
        }
    }

    StatusSearchLocationMenu {
        id: searchPopupMenu
        
        locationModel: root.locationMenuModel

        onItemClicked: (firstLevelItemValue, secondLevelItemValue) => {
            root.setSearchLocationFn(firstLevelItemValue, secondLevelItemValue)
            searchPopup.forceActiveFocus()
            if(searchPopup.searchText !== "")
                root.searchMessagesDebounced()
        }

        onResetSearchSelection: {
            searchPopup.resetSearchSelection()
        }

        onSetSearchSelection: (text, secondaryText, imageSource, isIdenticon, iconName, iconColor, isUserIcon, colorId) => {
            searchPopup.setSearchSelection(text,
                                            secondaryText,
                                            imageSource,
                                            isIdenticon,
                                            iconName,
                                            iconColor,
                                            isUserIcon,
                                            colorId)
        }
    }

    StatusSearchPopup {
        id: searchPopup
        fillHeightOnBottomSheet: true
        noResultsLabel: qsTr("No results")
        defaultSearchLocationText: qsTr("Anywhere")
        searchOptionsPopupMenu: searchPopupMenu
        searchResults: root.resultModel
        loading: root.searchInProgress
        formatTimestampFn: function (ts) {
            return LocaleUtils.formatDateTime(parseInt(ts, 10), Locale.ShortFormat)
        }
        onSearchTextChanged: {
            if (searchPopup.searchText !== "") {
                root.searchMessagesDebounced()
            } else {
                root.clearSearchResults()
            }
        }
        onAboutToHide: {
            if (searchPopupMenu.visible) {
                searchPopupMenu.close();
            }
        }
        onClosed: {
            searchPopupMenu.dismiss();
            root.clearSearchResults();
            root.closed();
        }
        onResetSearchLocationClicked: {
            searchPopup.resetSearchSelection();
            root.setSearchLocationFn("", "")
            root.searchMessagesDebounced()
        }
        onOpened: {
            searchPopup.resetSearchSelection();
            root.prepareLocationMenuModelFn()

            const jsonObj = root.getSearchLocationObjectFn()

            if (!jsonObj) {
                return
            }

            let obj = JSON.parse(jsonObj)
            if (obj.location === "" || (obj.location !== "" && !obj.subLocation)) {
                if(obj.subLocation === "") {
                    root.setSearchLocationFn("", "")
                } else {
                    searchPopup.setSearchSelection(obj.subLocation.text,
                                                   "",
                                                   obj.subLocation.imageSource,
                                                   false,
                                                   obj.subLocation.iconName,
                                                   obj.subLocation.identiconColor)

                    root.setSearchLocationFn("", obj.subLocation.value)
                }
            } else {
                if (obj.location.title === "Chat" && !!obj.subLocation) {
                    searchPopup.setSearchSelection(obj.subLocation.text,
                                                   "",
                                                   obj.subLocation.imageSource,
                                                   false,
                                                   obj.subLocation.iconName,
                                                   obj.subLocation.identiconColor,
                                                   obj.subLocation.isUserIcon,
                                                   obj.subLocation.colorId)

                    root.setSearchLocationFn(obj.location.value, obj.subLocation.value)
                } else {
                    searchPopup.setSearchSelection(obj.location.title,
                                                   obj.subLocation.text,
                                                   obj.location.imageSource,
                                                   false,
                                                   obj.location.iconName,
                                                   obj.location.identiconColor)

                    root.setSearchLocationFn(obj.location.value, obj.subLocation.value)
                }
            }
        }
        onResultItemClicked: (itemId) => {
            searchPopup.close()
            root.resultItemClicked(itemId)
        }
        acceptsTitleClick: function (titleId) {
            return root.isChatKeyFn(titleId)
        }
        onResultItemTitleClicked: (titleId) => {
            root.openProfilePopupFn(titleId, searchPopup)
        }
    }
}
