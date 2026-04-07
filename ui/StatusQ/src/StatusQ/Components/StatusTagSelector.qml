pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Core.Utils

/*!
     \qmltype StatusTagSelector
     \inherits Item
     \inqmlmodule StatusQ.Components
     \since StatusQ.Components 0.1
     \brief Displays a tag selector component together with a list of where to select and add the tags from.
     Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-item.html}{Item}.

     The \c StatusTagSelector displays a list of asorted elements together with a text input where tags are added. As the user
     types some text, the list elements are filtered and if the user selects any of those a new tag is created.
     For example:

     \qml
     StatusTagSelector {
        width: 650
        height: 44
        anchors.centerIn: parent
        namesModel: ListModel {
            ListElement {
                pubKey: "0x0"
                name: "Maria"
                icon: ""
                onlineStatus: 3
            }
            ListElement {
                pubKey: "0x1"
                name: "James"
                icon: "https://pbs.twimg.com/profile_images/1369221718338895873/T_5fny6o_400x400.jpg"
                onlineStatus: 1
            }
            ListElement {
                pubKey: "0x2"
                name: "Paul"
                icon: ""
                onlineStatus: 2
            }
        }
        toLabelText: qsTr("To: ")
        warningText: qsTr("USER LIMIT REACHED")
     }
     \endqml

     \image status_tag_selector.png

     For a list of components available see StatusQ.
  */

Item {
    id: root

    /*!
        \qmlproperty real StatusTagSelector::maxHeight
        This property holds the maximum height of the component.
    */
    property real maxHeight: (488 + contactsLabel.height + contactsLabel.anchors.topMargin) //default min
    /*!
        \qmlproperty alias StatusTagSelector::textEdit
        This property holds a reference to the TextEdit component.
    */
    property alias textEdit: edit
    /*!
        \qmlproperty alias StatusTagSelector::text
        This property holds a reference to the TextEdit's text property.
    */
    property alias text: edit.text
    /*!
        \qmlproperty string StatusTagSelector::warningText
        This property sets the warning text.
    */
    property string warningText: ""
    /*!
        \qmlproperty string StatusTagSelector::toLabelText
        This property sets the 'to' label text.
    */
    property string toLabelText: ""
    /*!
        \qmlproperty string StatusTagSelector::listLabel
        This property sets the elements list label text.
    */
    property string listLabel: ""
    /*!
        \qmlproperty int StatusTagSelector::nameCountLimit
        This property sets the tags count limit.
    */
    property int nameCountLimit: 5

    /*!
        \qmlproperty var StatusTagSelector::compressKeyGetter
        This property holds the function to calculate the compressed
        key based on the public key.
    */
    property var compressedKeyGetter: (pubKey) => { /*return compressed key;*/ }

    /*!
        \qmlproperty var StatusTagSelector::colorIdForPubkeyGetter
        This property holds the function to calculate the color Id
        based on the public key.
    */
    property var colorIdForPubkeyGetter: (pubKey) => { /*return color Id;*/ }

    /*!
        \qmlproperty ListModel StatusTagSelector::sortedList
        This property holds the sorted list model.
    */
    property ListModel sortedList: ListModel { }
    /*!
        \qmlproperty ListModel StatusTagSelector::namesModel
        This property holds the asorted names model.
    */
    property ListModel namesModel: ListModel { }
    /*!
        \qmlproperty bool StatusTagSelector::showSortedListOnlyWhenText
        This property will decide if the sorted list view info is displayed before entering some text in the input or after.
        By default is set to false.
    */
    property bool showSortedListOnlyWhenText: false
    /*!
        \qmlproperty bool StatusTagSelector::orderByReadonly
        This property will decide if the displayed tag names will be ordered from left to right starting with the items that are marked as `isReadonly`.
        By default is set to true (readonly names at left).
    */
    property bool orderByReadonly: true

    /*!
        \qmlmethod
        This function is used to find an entry in a model.
    */
    function find(model: var, criteria: var): var {
        for (var i = 0; i < model.count; ++i) if (criteria(model.get(i))) return model.get(i);
        return null;
    }

    /*!
        \qmlmethod
        This function is used to insert a new tag.
    */
    function insertTag(name: string, id: string, isReadonly: bool, tagIcon: string): void {
        if (!find(namesModel, function(item) { return item.pubKey === id }) && namesModel.count < root.nameCountLimit) {
            if(orderByReadonly && isReadonly)
                namesModel.insert(0, {"name": name, "pubKey": id, "isReadonly": !!isReadonly, "tagIcon": tagIcon ? tagIcon : ""});
            else
                namesModel.insert(namesModel.count, {"name": name, "pubKey": id, "isReadonly": !!isReadonly, "tagIcon": tagIcon ? tagIcon : ""});
            addMember(id);
            edit.clear();
        }
    }

    /*!
        \qmlmethod
        This function is used to sort the source model.
    */
    function sortModel(inputModel: var): void {
        sortedList.clear();
        if (text !== "") {
            for (var i = 0; i < inputModel.count; i++ ) {
                var entry = inputModel.get(i);
                if (entry.displayName.toLowerCase().includes(text.toLowerCase()) &&
                    !find(namesModel, function(item) { return item.name === entry.displayName })) {
                    sortedList.append({"pubKey": entry.pubKey,
                                       "displayName": entry.displayName,
                                       "localNickname": entry.localNickname,
                                       "isVerified": entry.isVerified,
                                       "isUntrustworthy": entry.isUntrustworthy,
                                       "isContact": entry.isContact,
                                       "icon": entry.icon,
                                       "isImage": entry.isImage,
                                       "onlineStatus": entry.onlineStatus,
                                       "tagIcon": entry.tagIcon ? entry.tagIcon : "",
                                       "isReadonly": !!entry.isReadonly});
                    userListView.model = sortedList;
                }
            }
        } else {
            userListView.model = inputModel;
        }
    }

    /*!
        \qmlsignal
        This signal is emitted when a new tag is created.
    */
    signal addMember(string memberId)

    /*!
        \qmlsignal
        This signal is emitted when a tag is removed.
    */
    signal removeMember(string memberId)

    QtObject {
        id: d

        property real suggestionContainerHeight: suggestionsContainer.visible ? contactsLabel.height + contactsLabel.anchors.topMargin +
                                                                                suggestionsContainer.anchors.topMargin + suggestionsContainer.anchors.bottomMargin +
                                                                                2 * bgRect.anchors.margins +
                                                                                userListView.anchors.topMargin + userListView.anchors.bottomMargin +
                                                                                (userListView.model.count * 64): 0

        function orderNamesModel() {
            if(root.orderByReadonly) {
                for(var i = 0; i < namesModel.count; i++) {
                    var entry = namesModel.get(i)
                    if(entry.isReadonly) {
                        namesModel.move(i, 0, 1)
                    }
                }
            }
        }
    }

    implicitWidth: 448
    implicitHeight: (tagSelectorRect.height + d.suggestionContainerHeight) > root.maxHeight ? root.maxHeight : (tagSelectorRect.height + d.suggestionContainerHeight)

    onOrderByReadonlyChanged: { d.orderNamesModel() }
    Component.onCompleted: {
        // Component initialization:
        d.orderNamesModel()
    }

    Rectangle {
        id: tagSelectorRect
        width: parent.width
        height: 44
        radius: 8
        color: Theme.palette.baseColor2
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 8
            StatusBaseText {
                Layout.preferredWidth: 22
                Layout.alignment: Qt.AlignVCenter
                font.pixelSize: Theme.primaryTextFontSize
                color: Theme.palette.baseColor1
                text: root.toLabelText
                visible: (parent.width>22)
            }

            StatusListView {
                id: namesList
                model: namesModel
                orientation: ListView.Horizontal
                spacing: 8
                function scrollToEnd() {
                    if (contentWidth > width) {
                        contentX = contentWidth;
                    }
                }

                implicitWidth: {
                    if (parent.width - 177 <= 0)
                        return 0
                    if (contentWidth > parent.width - 177)
                        return parent.width - 177
                    return contentWidth
                }
                implicitHeight: 30
                Layout.alignment: Qt.AlignVCenter

                onWidthChanged: { scrollToEnd(); }
                onCountChanged: { scrollToEnd(); }
                delegate: StatusTagItem {
                    isReadonly: model.isReadonly
                    text: model.name
                    icon: model.tagIcon

                    onClosed: {
                        removeMember(model.pubKey);
                        namesModel.remove(index, 1);
                    }
                }
            }

            TextInput {
                id: edit
                verticalAlignment: Text.AlignVCenter
                focus: !Utils.isMobile // Do not focus on mobile devices
                color: Theme.palette.directColor1
                clip: true
                font.pixelSize: Theme.primaryTextFontSize
                wrapMode: TextEdit.NoWrap
                font.family: Fonts.baseFont.family
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                visible: (parent.width>22)
                Keys.onPressed: function (event) {
                    if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape)
                            && getText(cursorPosition, (cursorPosition-1)) === ""
                            && (namesList.count-1) >= 0) {
                        const item = namesModel.get(namesList.count-1)
                        if (!item.isReadonly) {
                            removeMember(item.pubKey);
                            namesModel.remove((namesList.count-1), 1);
                        }
                    }
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (sortedList.count > 0)) {
                        root.insertTag(sortedList.get(userListView.currentIndex).name,
                                       sortedList.get(userListView.currentIndex).pubKey,
                                       sortedList.get(userListView.currentIndex).isReadonly,
                                       sortedList.get(userListView.currentIndex).tagIcon);
                    }                    
                }
                Keys.onUpPressed: { userListView.decrementCurrentIndex(); }
                Keys.onDownPressed: { userListView.incrementCurrentIndex(); }
            }

            StatusBaseText {
                id: warningTextLabel
                visible: (namesModel.count === root.nameCountLimit)
                Layout.preferredWidth: visible ? 120 : 0
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                font.pixelSize: Theme.asideTextFontSize
                color: Theme.palette.dangerColor1
                text: root.nameCountLimit + " " + root.warningText
            }
        }
    }

    StatusBaseText {
        id: contactsLabel
        font.pixelSize: Theme.primaryTextFontSize
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.top: tagSelectorRect.bottom
        anchors.topMargin: visible ? 32 : 0
        height: visible ? contentHeight : 0
        visible: (root.sortedList.count === 0)
        color: Theme.palette.baseColor1
        text: root.listLabel
    }

    Control {
        id: suggestionsContainer
        width: 360
        anchors {
            top: (root.sortedList.count > 0) ? tagSelectorRect.bottom : contactsLabel.bottom
            topMargin: Theme.halfPadding
            bottom: parent.bottom
            bottomMargin: Theme.padding
        }
        clip: true
        visible: (!root.showSortedListOnlyWhenText && ((root.sortedList.count > 0) || (edit.text === ""))) ||
                 ((edit.text !== "") && (root.sortedList.count > 0))
        x: ((root.namesModel.count > 0) && (root.sortedList.count > 0) && ((edit.x + 8) <= (root.width - suggestionsContainer.width)))
           ? (edit.x + 8) : 0
        background: Rectangle {
            id: bgRect
            anchors.fill: parent
            anchors.margins: 8
            visible: (root.sortedList.count > 0)
            color: Theme.palette.statusMenu.backgroundColor
            radius: 8
            layer.enabled: true
            layer.effect: DropShadow {
                source: bgRect
                horizontalOffset: 0
                verticalOffset: 4
                radius: 12
                samples: 25
                spread: 0.2
                color: Theme.palette.dropShadow
            }
        }
        contentItem: ListView {
            id: userListView
            objectName: "tagSelectorUserList"
            anchors {
                fill: parent
                topMargin: 16
                leftMargin: 8
                rightMargin: 8
            }
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            boundsBehavior: Flickable.StopAtBounds
            onCountChanged: {
                userListView.currentIndex = 0;
            }
            delegate: StatusMemberListItem {
                anchors.left: parent.left
                anchors.leftMargin: bgRect.visible ? 8 : 0
                anchors.right: parent.right
                anchors.rightMargin: bgRect.visible ? 8 : 0
                height: visible ? 64 : 0
                visible: {
                    for (let i = 0; i < namesModel.count; i++) {
                        if (namesModel.get(i).pubKey === model.pubKey) {
                            return false
                        }
                    }
                    return true
                }
                nickName: model.localNickname
                userName: model.displayName
                pubKey: root.compressedKeyGetter(model.pubKey)
                isVerified: model.isVerified
                isUntrustworthy: model.isUntrustworthy
                isContact: model.isContact
                icon.name: model.icon
                icon.color: Theme.palette.userCustomizationColors[root.colorIdForPubkeyGetter(model.pubKey)]
                status: model.onlineStatus
                color: (hovered || highlighted) ? Theme.palette.baseColor2 : "transparent"
                onClicked: {
                    root.insertTag(model.displayName, model.pubKey, model.isAdmin, model.isAdmin ? "crown" : "");
                }
            }
        }
    }
}
