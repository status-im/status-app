import unittest

import app_service/common/types
import app_service/service/contacts/dto/contact_details
import app_service/service/message/dto/message

import app/modules/shared_models/message_model
import app/modules/shared_models/message_item
import app/modules/shared_models/message_transaction_parameters_item

proc createTestMessageItem(id: string, clock: int64): Item =
  return message_model.createMessageItemFromDtos(
    message = MessageDto(
      id: id,
      clock: clock,
      contentType: ContentType.Unknown,
    ),
    communityId = "",
    sender = ContactDetails(),
    isCurrentUser = false,
    renderedMessageText = "",
    clearText = "",
  )

let message0_chatIdentifier = createTestMessageItem("chat-identifier", -2)
let message0_fetchMoreMessages = createTestMessageItem("fetch-more-messages", -1)
let message1 = createTestMessageItem("0xa", 1)
let message2 = createTestMessageItem("0xb", 2)
let message3 = createTestMessageItem("0xc", 3)
let message4 = createTestMessageItem("0xd", 3)
let message5 = createTestMessageItem("0xe", 4)

template checkOrder(model: Model) =
  require(model.items.len == 7)
  check(model.items[0].id == message5.id)
  check(model.items[1].id == message4.id)
  check(model.items[2].id == message3.id)
  check(model.items[3].id == message2.id)
  check(model.items[4].id == message1.id)
  check(model.items[5].id == message0_fetchMoreMessages.id)
  check(model.items[6].id == message0_chatIdentifier.id)

suite "empty model":
  let model = newModel()

  test "initial size":
    require(model.rowCount() == 0)

suite "outgoing status ordering":
  test "applies an early sent signal when the message is inserted":
    let model = newModel()
    model.itemSent(message1.id)
    model.insertItemBasedOnClock(message1)
    check(model.getItemWithMessageId(message1.id).outgoingStatus == PARSED_TEXT_OUTGOING_STATUS_SENT)

  test "keeps the highest early outgoing status":
    let model = newModel()
    model.itemSent(message1.id)
    model.itemDelivered(message1.id)
    model.insertItemBasedOnClock(message1)
    check(model.getItemWithMessageId(message1.id).outgoingStatus == PARSED_TEXT_OUTGOING_STATUS_DELIVERED)

# newest messages should be first, break ties by message id
suite "inserting new messages":
  setup:
    let model = newModel()
    model.insertItemsBasedOnClock(@[message0_fetchMoreMessages, message0_chatIdentifier])

  test "insert same message twice":
    model.insertItemBasedOnClock(message1)
    check(model.rowCount() == 3)
    model.insertItemBasedOnClock(message1)
    check(model.rowCount() == 3)

  test "insert in order":
    model.insertItemBasedOnClock(message1)
    check(model.rowCount() == 3)
    model.insertItemBasedOnClock(message2)
    check(model.rowCount() == 4)
    model.insertItemBasedOnClock(message3)
    check(model.rowCount() == 5)
    model.insertItemBasedOnClock(message4)
    check(model.rowCount() == 6)
    model.insertItemBasedOnClock(message5)
    check(model.rowCount() == 7)
    checkOrder(model)

  test "insert out of order":
    model.insertItemBasedOnClock(message5)
    check(model.rowCount() == 3)
    model.insertItemBasedOnClock(message4)
    check(model.rowCount() == 4)
    model.insertItemBasedOnClock(message3)
    check(model.rowCount() == 5)
    model.insertItemBasedOnClock(message2)
    check(model.rowCount() == 6)
    model.insertItemBasedOnClock(message1)
    check(model.rowCount() == 7)
    checkOrder(model)

  test "insert out of order (randomly)":
    model.insertItemBasedOnClock(message3)
    check(model.rowCount() == 3)
    model.insertItemBasedOnClock(message1)
    check(model.rowCount() == 4)
    model.insertItemBasedOnClock(message4)
    check(model.rowCount() == 5)
    model.insertItemBasedOnClock(message2)
    check(model.rowCount() == 6)
    model.insertItemBasedOnClock(message5)
    check(model.rowCount() == 7)
    checkOrder(model)

suite "inserting multiple new messages":
  setup:
    let model = newModel()
    model.insertItemsBasedOnClock(@[message0_fetchMoreMessages, message0_chatIdentifier])

  test "insert to empty model":
    model.insertItemsBasedOnClock(@[message5,
                                    message4,
                                    message3,
                                    message2,
                                    message1])
    checkOrder(model)

  test "insert to model with only newer messages":
    model.insertItemBasedOnClock(message5)
    model.insertItemBasedOnClock(message4)
    model.insertItemsBasedOnClock(@[message3,
                                    message2,
                                    message1])
    checkOrder(model)

  test "insert to model with only older messages":
    model.insertItemBasedOnClock(message2)
    model.insertItemBasedOnClock(message1)
    model.insertItemsBasedOnClock(@[message5,
                                    message4,
                                    message3])
    checkOrder(model)

  test "insert to model with newer and older messages":
    model.insertItemBasedOnClock(message5)
    model.insertItemBasedOnClock(message1)
    model.insertItemsBasedOnClock(@[message4,
                                    message3,
                                    message2])
    checkOrder(model)

  test "insert to model with newer and older messages and some in between":
    model.insertItemBasedOnClock(message5)
    model.insertItemBasedOnClock(message1)
    model.insertItemBasedOnClock(message3) # in between
    model.insertItemsBasedOnClock(@[message4,
                                    message2])
    checkOrder(model)

suite "new messages marker":
  setup:
    let model = newModel()
    model.insertItemsBasedOnClock(@[message0_fetchMoreMessages, message0_chatIdentifier])

  test "set new messages marker":
    model.insertItemsBasedOnClock(@[message1,
                                    message2])
    require(model.items.len == 4)

    # add new messages marker
    model.setFirstUnseenMessageId(message2.id)
    model.resetNewMessagesMarker()

    require(model.items.len == 5)
    check(model.items[0].id == message2.id)
    check(model.items[1].contentType == ContentType.NewMessagesMarker)
    check(model.items[2].id == message1.id)
    check(model.items[3].id == message0_fetchMoreMessages.id)
    check(model.items[4].id == message0_chatIdentifier.id)

  test "remove new messages marker":
    model.insertItemsBasedOnClock(@[message1,
                                    message2])
    require(model.items.len == 4)

    # add new messages marker
    model.setFirstUnseenMessageId(message2.id)
    model.resetNewMessagesMarker()
    require(model.items.len == 5)

    # remove new messages marker
    model.setFirstUnseenMessageId("")
    model.resetNewMessagesMarker()
    require(model.items.len == 4)
    check(model.items[0].id == message2.id)
    check(model.items[1].id == message1.id)
    check(model.items[2].id == message0_fetchMoreMessages.id)
    check(model.items[3].id == message0_chatIdentifier.id)

suite "simulations":
  setup:
    let model = newModel()
    model.insertItemsBasedOnClock(@[message0_fetchMoreMessages, message0_chatIdentifier])

  test "simulate messages loading":
    # load first two messages
    var loadedMessages: seq[Item]
    loadedMessages.add(message5)
    loadedMessages.add(message4)
    model.removeItem(message0_fetchMoreMessages.id)
    model.removeItem(message0_chatIdentifier.id)
    loadedMessages.add(message0_fetchMoreMessages)
    loadedMessages.add(message0_chatIdentifier)
    model.insertItemsBasedOnClock(loadedMessages)

    require(model.items.len == 4)
    check(model.items[0].id == message5.id)
    check(model.items[1].id == message4.id)
    check(model.items[2].id == message0_fetchMoreMessages.id)
    check(model.items[3].id == message0_chatIdentifier.id)

    # set new messages marker
    model.setFirstUnseenMessageId(message5.id)
    model.resetNewMessagesMarker()

    require(model.items.len == 5)
    check(model.items[0].id == message5.id)
    check(model.items[1].contentType == ContentType.NewMessagesMarker)
    check(model.items[2].id == message4.id)
    check(model.items[3].id == message0_fetchMoreMessages.id)
    check(model.items[4].id == message0_chatIdentifier.id)

    # load next two messages
    loadedMessages = @[]
    loadedMessages.add(message3)
    loadedMessages.add(message2)
    model.removeItem(message0_fetchMoreMessages.id)
    model.removeItem(message0_chatIdentifier.id)
    loadedMessages.add(message0_fetchMoreMessages)
    loadedMessages.add(message0_chatIdentifier)
    model.insertItemsBasedOnClock(loadedMessages)

    require(model.items.len == 7)
    check(model.items[0].id == message5.id)
    check(model.items[1].contentType == ContentType.NewMessagesMarker)
    check(model.items[2].id == message4.id)
    check(model.items[3].id == message3.id)
    check(model.items[4].id == message2.id)
    check(model.items[5].id == message0_fetchMoreMessages.id)
    check(model.items[6].id == message0_chatIdentifier.id)

    # load last message
    loadedMessages = @[]
    loadedMessages.add(message1)
    model.removeItem(message0_fetchMoreMessages.id)
    model.removeItem(message0_chatIdentifier.id)
    loadedMessages.add(message0_fetchMoreMessages)
    loadedMessages.add(message0_chatIdentifier)
    model.insertItemsBasedOnClock(loadedMessages)

    require(model.items.len == 8)
    check(model.items[0].id == message5.id)
    check(model.items[1].contentType == ContentType.NewMessagesMarker)
    check(model.items[2].id == message4.id)
    check(model.items[3].id == message3.id)
    check(model.items[4].id == message2.id)
    check(model.items[5].id == message1.id)
    check(model.items[6].id == message0_fetchMoreMessages.id)
    check(model.items[7].id == message0_chatIdentifier.id)

  test "simulate chat identifier update":
    model.insertItemsBasedOnClock(@[message5,
                                    message4,
                                    message3,
                                    message2,
                                    message1])
    checkOrder(model)

    # set new messages marker
    model.setFirstUnseenMessageId(message4.id)
    model.resetNewMessagesMarker()

    # update chat identifier
    model.removeItem(message0_chatIdentifier.id)
    model.insertItemBasedOnClock(message0_chatIdentifier)

    require(model.items.len == 8)
    check(model.items[0].id == message5.id)
    check(model.items[1].id == message4.id)
    check(model.items[2].contentType == ContentType.NewMessagesMarker)
    check(model.items[3].id == message3.id)
    check(model.items[4].id == message2.id)
    check(model.items[5].id == message1.id)
    check(model.items[6].id == message0_fetchMoreMessages.id)
    check(model.items[7].id == message0_chatIdentifier.id)


suite "mark as seen":
  setup:
    let model = newModel()

    var msg1 = createTestMessageItem("0xa", 1)
    msg1.seen=false
    let msg2 = createTestMessageItem("0xb", 2)
    msg2.seen=false
    let msg3 = createTestMessageItem("0xc", 3)
    msg3.seen=true

    model.insertItemsBasedOnClock(@[msg1, msg2, msg3])
    require(model.items.len == 3)
    check(model.items[0].seen == true)
    check(model.items[1].seen == false)
    check(model.items[2].seen == false)

  test "mark all as seen":
    model.markAllAsSeen()
    check(model.items[0].seen == true)
    check(model.items[1].seen == true)
    check(model.items[2].seen == true)

  test "mark some as seen":
    model.markAsSeen(@["0xa"])
    check(model.items[0].seen == true)
    check(model.items[1].seen == false)
    check(model.items[2].seen == true)

    model.markAsSeen(@["0xb"])
    check(model.items[0].seen == true)
    check(model.items[1].seen == true)
    check(model.items[2].seen == true)

suite "mark message as unread":
  setup:
    let model = newModel()

    var msg1 = createTestMessageItem("0xa", 1)
    msg1.seen = true
    var msg2 = createTestMessageItem("0xb", 2)
    msg2.seen = true
    var msg3 = createTestMessageItem("0xc", 3)
    msg3.seen = true

    model.insertItemsBasedOnClock(@[msg1, msg2, msg3])
    require(model.items.len == 3)
    check(model.items[0].seen == true)
    check(model.items[1].seen == true)
    check(model.items[2].seen == true)

  test "mark message as unread":
    model.markMessageAsUnread("0xa")
    check(model.items[2].seen == false)

    model.markMessageAsUnread("0xb")
    check(model.items[1].seen == false)

    model.markMessageAsUnread("0xc")
    check(model.items[0].seen == false)

  test "mark an already unread message as unread":
    model.markMessageAsUnread("0xa")
    check(model.items[2].seen == false)
    model.markMessageAsUnread("0xa")
    check(model.items[2].seen == false)

    model.markMessageAsUnread("0xb")
    check(model.items[1].seen == false)
    model.markMessageAsUnread("0xb")
    check(model.items[1].seen == false)

    model.markMessageAsUnread("0xc")
    check(model.items[0].seen == false)
    model.markMessageAsUnread("0xc")
    check(model.items[0].seen == false)

  test "mark all messages as unread":
    require(model.items.len == 3)

    model.markMessageAsUnread("0xa")
    model.markMessageAsUnread("0xc")
    model.markMessageAsUnread("0xb")


    # Because new row is inserted for message marker
    require(model.items.len == 4)

    check(model.items[0].seen == false)
    check(model.items[1].seen == false)

    # message marker is inserted on top of the last inserted element
    # last inserted element is `0xc` which is at position 0
    # and marker is insert last at position : position('0xb') - 1 equals to position 2 here
    check(model.items[2].seen == true)
    check(model.items[3].seen == false)
