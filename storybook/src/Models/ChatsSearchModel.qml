import QtQuick
import StatusQ.Components

ListModel {
    ListElement {
        chatId: "id1"
        chatType: StatusChatListItem.Type.OneToOneChat
        name: "John Doe"
        color: ""
        colorId: 3
        icon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACkAAAAoCAYAAABjPNNTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAALiSURBVHgB1ZhPTxNBGId/24IWYiIeNEUikkg1EtL2APRSYoKUNl5EvEhjgn4Ba3rxqEc92MgXUE/WE9GDxCKSEIkJcqnBQAyYkCqIxQChBLG1xX2n2dp/6u7sbFOepNnuzM7uk3fm3ZlZ6f7NF9ekPekRqhQJ0uMaCGZ96xsWv8zmzrvaeqEX4ZKfZMGnr0K586qTDMtyG1txiEao5MzcOIxAiGR4LISZeWMECV2SSpKsJ8R3cT66JIuTxChM4ISSRE0Xs+t0jlXuSKp9sHJdp45XkWZJJUkWnt8pqbNd/FN290Y/Lp93sv8jE1EEhy9g0BPkklXd3ZQk7+So2E7WYaAn+3CTuRY1dYfZkaDyrvaWkrZNxxpY3Y9UjN3DMEklSeynzbgX6M82PlgPy5HjMMtHgsqV6OXjksWpzmRa5Eo07jFpaWhEJp3C7sYKMsmdEiFXmYjywi1ZU9+AXzubSCa+F5QrXSsSbsntlXlUCtWSzc0n4Pf70Wp3wmJtAQ/nepNy2zZoRbWk292N7kvXoYehM30Yko8Pb7/V1E615NTUGzZ7UDTdbjcre//VjJcLtQXXORvT8NpSqI1EYI5GC+pSPh/SDge0oloyFvssSz7JCRKr2yZEiiQJkiRBEs0n7XRySap6T9Js8TM9wWYZT1Mca5MPUEl0rYKshzLwtaYKyhxydxMUNUhSQV3GagUPuiRJSJEqJuX1sp8IVEtOf1jCreFnGJCnPZpNEh/HoJWR11F2n46jVzW1Uy25HN9kqxlaQLjagd3VOWhlcnyU3aMjYIBkKDDK1oVhFYsDkqCIK5Rb0mlF+L67qubuv+Fiw6EFIuHe4+RT3MWiESI5PbvERI1CSHfTIpd++XschapLHNEJoyBUUtn7iEZ4dpdDGbN76VZc8fRAK0IS538sr2VnK8uBZq7vlUIiSa+ff2U3fRCgWYsXod3debZ8lE412aEHoZKDfUEYQUXGpF72heRvWCUEXU7sGx8AAAAASUVORK5CYII="
        sectionId: "section1"
        sectionName: "Messages"
        emoji: ""
        lastMessageText: ""
    }
    ListElement {
        chatId: "id2"
        chatType: StatusChatListItem.Type.CommunityChat
        name: "welcome"
        color: "lightsalmon"
        colorId: 0
        icon: ""
        sectionId: "section2"
        sectionName: "ACME Community"
        emoji: "💩"
        lastMessageText: "So long and thx for the fish..."
    }
    ListElement {
        chatId: "id3"
        chatType: StatusChatListItem.Type.GroupChat
        name: "Cool Gang"
        color: "mintcream"
        colorId: 0
        icon: ""
        sectionId: "section3"
        sectionName: "Messages"
        emoji: ""
        lastMessageText: ""
    }
}
