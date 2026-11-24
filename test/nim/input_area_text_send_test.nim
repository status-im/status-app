import std/[importutils, json, sets, unittest]
import app/core/[eventemitter, unique_event_emitter]
import app/modules/main/chat_section/chat_content/input_area/controller as input_controller
import app/modules/main/chat_section/chat_content/input_area/io_interface as input_interface
import app/modules/main/chat_section/chat_content/input_area/view as input_view
import app/modules/main/chat_section/chat_content/input_area/preserved_properties
import app_service/service/chat/service as chat_service
import app_service/service/message/dto/[link_preview, payment_request]

privateAccess(input_controller.Controller)
privateAccess(input_view.View)

type Delegate = ref object of input_interface.AccessInterface
  sends: seq[tuple[msg, replyTo: string, contentType: int, sendToken: string]]
  completions: seq[(string, string)]
  composerCompletions: int

method sendChatMessage(self: Delegate, msg: string, replyTo: string, contentType: int,
    linkPreviews: seq[LinkPreview], paymentRequests: seq[PaymentRequest], startNewThread: bool,
    newThreadName: string, sendToken: string = "") =
  check linkPreviews.len == 0
  check paymentRequests.len == 0
  check not startNewThread
  self.sends.add((msg, replyTo, contentType, sendToken))

method onTextMessageSent(self: Delegate, requestId, error: string) =
  self.completions.add((requestId, error))

method onComposerSendFinished(self: Delegate) =
  inc self.composerCompletions

suite "isolated text sends":
  test "text slot preserves the parent composer and rejects blank or uncorrelated sends":
    let delegate = Delegate()
    let view = input_view.newView(delegate)
    defer: view.delete()
    view.preservedProperties.setText("Unsent parent draft")
    check not view.sendTextMessage(" \n ", 1, "request", "parent")
    check not view.sendTextMessage("Reply", 1, "", "parent")
    check view.sendTextMessage("Reply", 1, "request", "parent")
    check view.sendTextMessage("Message", 1, "plain-request", "")
    check delegate.sends == @[("Reply", "parent", 1, "request"), ("Message", "", 1, "plain-request")]
    check view.preservedProperties.getText() == "Unsent parent draft"

  test "only the matching request completes and duplicate results are ignored":
    let events = createEventEmitter()
    let delegate = Delegate()
    let controller = input_controller.Controller(delegate: delegate, chatId: "chat",
      events: initUniqueUUIDEventEmitter(events), textSendTokens: toHashSet(["request", "retry"]))
    controller.init()
    defer: controller.delete()
    events.emit(chat_service.SIGNAL_SENDING_FINISHED,
      chat_service.SendingFinishedArgs(chatId: "other-chat", sendToken: "request"))
    events.emit(chat_service.SIGNAL_SENDING_FINISHED,
      chat_service.SendingFinishedArgs(chatId: "chat", sendToken: "other-request"))
    check delegate.completions.len == 0
    events.emit(chat_service.SIGNAL_SENDING_FINISHED,
      chat_service.SendingFinishedArgs(chatId: "chat", sendToken: "request", error: "Offline"))
    events.emit(chat_service.SIGNAL_SENDING_FINISHED,
      chat_service.SendingFinishedArgs(chatId: "chat", sendToken: "request"))
    events.emit(chat_service.SIGNAL_SENDING_FINISHED,
      chat_service.SendingFinishedArgs(chatId: "chat", sendToken: "retry"))
    check delegate.completions == @[("request", "Offline"), ("retry", "")]

  test "async persistence errors retain their chat and request correlation":
    let events = createEventEmitter()
    let service = chat_service.newService(events, nil, nil)
    var completions: seq[chat_service.SendingFinishedArgs]
    events.on(chat_service.SIGNAL_SENDING_FINISHED) do(args: Args):
      completions.add(chat_service.SendingFinishedArgs(args))
    service.onAsyncSendMessageDone($(%* {
      "chatId": "chat", "sendToken": "request", "error": "Persistence failed"
    }))
    check completions.len == 1
    check completions[0].chatId == "chat"
    check completions[0].sendToken == "request"
    check completions[0].error == "Persistence failed"

  test "overlapping channel and thread sends only release their own composer":
    let events = createEventEmitter()
    let service = chat_service.newService(events, nil, nil)
    let channel = Delegate()
    let thread = Delegate()
    let channelController = input_controller.Controller(delegate: channel, chatId: "chat",
      events: initUniqueUUIDEventEmitter(events), composerSendTokens: toHashSet(["channel-send"]))
    let threadController = input_controller.Controller(delegate: thread, chatId: "chat",
      events: initUniqueUUIDEventEmitter(events), composerSendTokens: toHashSet(["thread-send"]),
      textSendTokens: toHashSet(["independent"]))
    channelController.init()
    threadController.init()
    defer:
      channelController.delete()
      threadController.delete()

    events.emit(chat_service.SIGNAL_SENDING_FINISHED,
      chat_service.SendingFinishedArgs(chatId: "chat", threadId: "thread", sendToken: "independent"))
    check thread.completions == @[("independent", "")]
    check channel.composerCompletions == 0
    check thread.composerCompletions == 0

    service.onAsyncSendMessageDone($(%* {
      "chatId": "chat", "threadId": "thread", "sendToken": "thread-send", "error": "Offline"
    }))
    check thread.composerCompletions == 1
    check channel.composerCompletions == 0

    events.emit(chat_service.SIGNAL_SENDING_FINISHED,
      chat_service.SendingFinishedArgs(chatId: "chat", sendToken: "channel-send"))
    check channel.composerCompletions == 1
    check thread.composerCompletions == 1
