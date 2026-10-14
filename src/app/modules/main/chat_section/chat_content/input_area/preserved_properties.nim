import nimqml

QtObject:
  type
    PreservedProperties* = ref object of QObject
      text: string
      mentionNamesJson: string
      replyMessageId: string
      fileUrlsAndSourcesJson: string

  proc setup(self: PreservedProperties)
  proc delete*(self: PreservedProperties)
  proc newPreservedProperties*(): PreservedProperties =
    new(result, delete)
    result.setup

  proc textChanged*(self: PreservedProperties) {.signal.}
  proc setText*(self: PreservedProperties, value: string) {.slot.} =
    if self.text == value:
      return
    self.text = value
    self.textChanged()
  proc getText*(self: PreservedProperties): string {.slot.} =
    result = self.text
  QtProperty[string] text:
    read = getText
    write = setText
    notify = textChanged

  # { pubKey: name } of the mentions in `text`, as they were shown when it was saved
  proc mentionNamesJsonChanged*(self: PreservedProperties) {.signal.}
  proc setMentionNamesJson*(self: PreservedProperties, value: string) {.slot.} =
    if self.mentionNamesJson == value:
      return
    self.mentionNamesJson = value
    self.mentionNamesJsonChanged()
  proc getMentionNamesJson*(self: PreservedProperties): string {.slot.} =
    result = self.mentionNamesJson
  QtProperty[string] mentionNamesJson:
    read = getMentionNamesJson
    write = setMentionNamesJson
    notify = mentionNamesJsonChanged

  proc replyMessageIdChanged*(self: PreservedProperties) {.signal.}
  proc setReplyMessageId*(self: PreservedProperties, value: string) {.slot.}=
    if self.replyMessageId == value:
      return
    self.replyMessageId = value
    self.replyMessageIdChanged()
  proc getReplyMessageId*(self: PreservedProperties): string {.slot.} =
    result = self.replyMessageId
  QtProperty[string] replyMessageId:
    read = getReplyMessageId
    write = setReplyMessageId
    notify = replyMessageIdChanged

  proc fileUrlsAndSourcesJsonChanged*(self: PreservedProperties) {.signal.}
  proc setFileUrlsAndSourcesJson*(self: PreservedProperties, value: string) {.slot.}=
    if self.fileUrlsAndSourcesJson == value:
      return
    self.fileUrlsAndSourcesJson = value
    self.fileUrlsAndSourcesJsonChanged()
  proc getFileUrlsAndSourcesJson*(self: PreservedProperties): string {.slot.} =
    result = self.fileUrlsAndSourcesJson
  QtProperty[string] fileUrlsAndSourcesJson:
    read = getFileUrlsAndSourcesJson
    write = setFileUrlsAndSourcesJson
    notify = fileUrlsAndSourcesJsonChanged

  proc setup(self: PreservedProperties) =
    self.QObject.setup
    self.fileUrlsAndSourcesJson = "[]"

  proc delete*(self: PreservedProperties) =
    self.QObject.delete

