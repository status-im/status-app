import nimqml, json, strutils, sequtils

import ./io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc parseCommunitySharedUrl*(self: View, url: string): string {.slot.} =
    return self.delegate.parseCommunitySharedUrl(url)

  proc parseCommunityChannelSharedUrl*(self: View, url: string): string {.slot.} =
    return self.delegate.parseCommunityChannelSharedUrl(url)

  proc parseContactSharedUrl*(self: View, url: string): string {.slot.} =
    return self.delegate.parseContactSharedUrl(url)

  proc createMessageUrl*(self: View, chatId: string, messageId: string): string {.slot.} =
    return self.delegate.createMessageUrl(chatId, messageId)

  proc delete*(self: View) =
    self.QObject.delete

