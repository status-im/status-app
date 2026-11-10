import QtQuick
import QtTest

import AppLayouts.Browser

Item {
    id: root

    Component {
        id: offerComponent

        DefaultViewerOffer {
            // What the platform says about a type, else about every type.
            property var platform: ({})
            property string platformAll: "none"
            property bool wanted: true
            property var offers: []
            property int dismissals: 0

            fileTypeFn: file => ({ pdf: "application/pdf", png: "image/png", mp3: "audio/mpeg",
                                   html: "text/html" })[file.split(".").pop()] ?? ""
            defaultViewerFn: type => platform[type] ?? platformAll
            offerFn: type => { offers = offers.concat([type]); return true }
            suggestedFn: () => wanted
            dismissFn: () => { dismissals++; wanted = false }
        }
    }

    Component {
        id: platformOfferComponent

        DefaultViewerOffer {}
    }

    TestCase {
        name: "DefaultViewerOffer"

        function makeOffer(props) {
            return createTemporaryObject(offerComponent, root, props ?? {})
        }

        // The desktop has no default viewer to offer.
        function test_thePlatformIsReachedAndOffersNothingHere() {
            const offer = createTemporaryObject(platformOfferComponent, root)
            compare(offer.defaultViewerFn("application/pdf"), "")
            compare(offer.offerFn("application/pdf"), false)
            compare(offer.fileTypeFn("file:///tmp/report.pdf"), "")
            compare(offer.suggestedFn(), true)
        }

        function test_offeredWhileAFileShowsAndAndroidAsksEachTime() {
            const offer = makeOffer({ openedFile: "content://media/doc/report.pdf" })
            verify(offer.shown)
            compare(offer.typeName, "PDFs")
        }

        function test_offeredForEveryTypeStatusClaims() {
            const offer = makeOffer({ openedFile: "content://media/doc/photo.png" })
            verify(offer.shown)
            compare(offer.typeName, "PNG images")
            offer.openedFile = "content://media/doc/song.mp3"
            verify(offer.shown)
            compare(offer.typeName, "MP3 audio")
        }

        function test_notOfferedForATypeStatusDoesNotClaim() {
            const offer = makeOffer({ openedFile: "content://media/doc/page.html" })
            verify(!offer.shown)
            compare(offer.typeName, "")
        }

        function test_offeredWhenATabStartsShowingAFile() {
            const offer = makeOffer({ openedFile: "" })
            offer.openedFile = "content://media/doc/report.pdf"
            verify(offer.shown)
        }

        function test_notOfferedWithoutAnOpenedFile() {
            const offer = makeOffer({ openedFile: "" })
            verify(!offer.shown)
        }

        function test_notOfferedOnceStatusOpensTheType() {
            const offer = makeOffer({ platformAll: "self", openedFile: "content://media/doc/report.pdf" })
            verify(!offer.shown)
        }

        function test_notOfferedWhereThePlatformCannotTell() {
            const offer = makeOffer({ platformAll: "", openedFile: "content://media/doc/report.pdf" })
            verify(!offer.shown)
        }

        // The user chose that app for the type after Status was installed.
        function test_notOfferedWhenAnotherAppOpensTheType() {
            const offer = makeOffer({ platformAll: "other:Drive", openedFile: "content://media/doc/report.pdf" })
            verify(!offer.shown)
        }

        function test_notOfferedWhenTheUserTurnedItOff() {
            const offer = makeOffer({ wanted: false, openedFile: "content://media/doc/report.pdf" })
            verify(!offer.shown)
        }

        function test_dismissingHidesTheOfferForEveryTypeAndTellsTheHost() {
            const offer = makeOffer({ openedFile: "content://media/doc/report.pdf" })
            offer.dismiss()
            verify(!offer.shown)
            compare(offer.dismissals, 1)
            offer.openedFile = "content://media/doc/photo.png"
            verify(!offer.shown)
        }

        function test_readsTheUsersChoiceAgainOnRefresh() {
            const offer = makeOffer({ wanted: false, openedFile: "content://media/doc/report.pdf" })
            offer.wanted = true
            offer.refresh()
            verify(offer.shown)
        }

        function test_acceptingAsksTheSystemAboutTheTypeAndHidesItsOffer() {
            const offer = makeOffer({ openedFile: "content://media/doc/report.pdf" })
            offer.accept()
            compare(offer.offers, ["application/pdf"])
            verify(!offer.shown)
            compare(offer.dismissals, 0)
        }

        function test_stillOffersAnotherTypeAfterAnAnswer() {
            const offer = makeOffer({ openedFile: "content://media/doc/report.pdf" })
            offer.accept()
            offer.openedFile = "content://media/doc/photo.png"
            verify(offer.shown)
        }

        function test_confirmsWhenStatusOpensTheTypeAfterTheOffer() {
            const offer = makeOffer({ openedFile: "content://media/doc/report.pdf" })
            offer.accept()
            verify(!offer.confirmed)
            offer.platformAll = "self"
            offer.refresh()
            verify(offer.confirmed)
            verify(!offer.shown)
        }

        function test_confirmationGoesOnceAcknowledged() {
            const offer = makeOffer({ openedFile: "content://media/doc/report.pdf" })
            offer.accept()
            offer.platformAll = "self"
            offer.refresh()
            offer.acknowledge()
            verify(!offer.confirmed)
        }

        function test_confirmationStaysWithItsType() {
            const offer = makeOffer({ openedFile: "content://media/doc/report.pdf" })
            offer.accept()
            offer.platformAll = "self"
            offer.refresh()
            offer.openedFile = "content://media/doc/photo.png"
            verify(!offer.confirmed)
        }

        function test_noConfirmationWhenStatusAlreadyOpenedTheType() {
            const offer = makeOffer({ platformAll: "self", openedFile: "content://media/doc/report.pdf" })
            offer.refresh()
            verify(!offer.confirmed)
        }

        function test_noConfirmationForATypeItDidNotAskAbout() {
            const offer = makeOffer({ openedFile: "content://media/doc/report.pdf" })
            offer.accept()
            offer.platform = { "image/png": "self" }
            offer.openedFile = "content://media/doc/photo.png"
            verify(!offer.confirmed)
        }

        function test_asksThePlatformAboutTheShownType() {
            const offer = makeOffer({ platform: { "application/pdf": "self" },
                                      openedFile: "content://media/doc/report.pdf" })
            verify(!offer.shown)
            offer.openedFile = "content://media/doc/photo.png"
            verify(offer.shown)
        }
    }
}
