import QtQuick
import StatusQ.Components

ListModel {
    ListElement {
        itemId: "id0"
        categoryId: "id0"
        active: false
        notificationsCount: 0
        hasUnreadMessages: false
        name: "Category X"
        emoji: ""
        icon: ""
        isCategory: true
        categoryOpened: true
        muted: false
        lastMessageText: ""
    }
    ListElement {
        itemId: "id1"
        type: StatusChatListItem.Type.OneToOneChat
        onlineStatus: 1 //Constants.onlineStatus.online
        name: "Punxnotdead"
        categoryId: "id0"
        active: false
        notificationsCount: 0
        hasUnreadMessages: false
        color: ""
        colorId: 1
        emoji: ""
        icon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACkAAAAoCAYAAABjPNNTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAALiSURBVHgB1ZhPTxNBGId/24IWYiIeNEUikkg1EtL2APRSYoKUNl5EvEhjgn4Ba3rxqEc92MgXUE/WE9GDxCKSEIkJcqnBQAyYkCqIxQChBLG1xX2n2dp/6u7sbFOepNnuzM7uk3fm3ZlZ6f7NF9ekPekRqhQJ0uMaCGZ96xsWv8zmzrvaeqEX4ZKfZMGnr0K586qTDMtyG1txiEao5MzcOIxAiGR4LISZeWMECV2SSpKsJ8R3cT66JIuTxChM4ISSRE0Xs+t0jlXuSKp9sHJdp45XkWZJJUkWnt8pqbNd/FN290Y/Lp93sv8jE1EEhy9g0BPkklXd3ZQk7+So2E7WYaAn+3CTuRY1dYfZkaDyrvaWkrZNxxpY3Y9UjN3DMEklSeynzbgX6M82PlgPy5HjMMtHgsqV6OXjksWpzmRa5Eo07jFpaWhEJp3C7sYKMsmdEiFXmYjywi1ZU9+AXzubSCa+F5QrXSsSbsntlXlUCtWSzc0n4Pf70Wp3wmJtAQ/nepNy2zZoRbWk292N7kvXoYehM30Yko8Pb7/V1E615NTUGzZ7UDTdbjcre//VjJcLtQXXORvT8NpSqI1EYI5GC+pSPh/SDge0oloyFvssSz7JCRKr2yZEiiQJkiRBEs0n7XRySap6T9Js8TM9wWYZT1Mca5MPUEl0rYKshzLwtaYKyhxydxMUNUhSQV3GagUPuiRJSJEqJuX1sp8IVEtOf1jCreFnGJCnPZpNEh/HoJWR11F2n46jVzW1Uy25HN9kqxlaQLjagd3VOWhlcnyU3aMjYIBkKDDK1oVhFYsDkqCIK5Rb0mlF+L67qubuv+Fiw6EFIuHe4+RT3MWiESI5PbvERI1CSHfTIpd++XschapLHNEJoyBUUtn7iEZ4dpdDGbN76VZc8fRAK0IS538sr2VnK8uBZq7vlUIiSa+ff2U3fRCgWYsXod3debZ8lE412aEHoZKDfUEYQUXGpF72heRvWCUEXU7sGx8AAAAASUVORK5CYII="
        muted: false
        isCategory: false
        categoryOpened: true
        lastMessageText: "https://status.app/c/iwuAChYKBGZld2YSA2ZldxgCIgcjODhCMEZGAw==#zQ3shk6ceLwoMYCZnV29hwkRfRMEiw6nFrpViCoLucaycPu9y"
    }
    ListElement {
        itemId: "id2"
        categoryId: "id2"
        name: "Category Y"
        active: false
        notificationsCount: 12
        hasUnreadMessages: false
        color: ""
        colorId: 2
        emoji: ""
        icon: ""
        isCategory: true
        categoryOpened: false
        muted: false
        lastMessageText: ""
    }
    ListElement {
        itemId: "id3"
        categoryId: "id2"
        type: StatusChatListItem.Type.CommunityChat
        name: "Channel Y_1"
        emoji: "💩"
        active: false
        notificationsCount: 0
        hasUnreadMessages: true
        color: ""
        colorId: 2
        icon: ""
        muted: false
        isCategory: false
        categoryOpened: true
        lastMessageText: "Long message consectetur adipiscing elit. Nulla tincidunt purus risus, sit amet dapibus nisi aliquam nec. In tristique risus nec tempus tempus. Vivamus quis sapien vitae ex iaculis fringilla quis in ipsum. Aenean lorem urna, gravida eget dignissim et, viverra nec ante. Fusce mi mauris, viverra sit amet leo ullamcorper, pretium gravida libero."
    }
    ListElement {
        itemId: "id4"
        categoryId: "id2"
        name: "Channel Y_2"
        active: false
        notificationsCount: 0
        hasUnreadMessages: false
        color: "red"
        colorId: 3
        icon: ""
        muted: false
        isCategory: false
        categoryOpened: true
        lastMessageText: "bold break line italic"
    }
    ListElement {
        itemId: "id5"
        type: StatusChatListItem.Type.GroupChat
        categoryId: "id2"
        name: "Channel Y_3"
        active: false
        notificationsCount: 1
        hasUnreadMessages: false
        color: ""
        colorId: 4
        emoji: ""
        icon: "https://assets.coingecko.com/coins/images/17139/standard/10631.png"
        muted: false
        isCategory: false
        categoryOpened: true
        lastMessageText: "💩"
    }
}
