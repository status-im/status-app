import nimqml, tables

# Where the reader was in the chat and in each of its threads (by thread id,
# "" for the chat itself), as recorded by the messages view, so that it
# outlives the view; and a message to jump to that the view has not taken yet
# (asked for while the view did not exist), which beats the record
QtObject:
  type
    ReadingPositions* = ref object of QObject
      records: Table[string, string]
      jump: string

  proc setup(self: ReadingPositions)
  proc delete*(self: ReadingPositions)
  proc newReadingPositions*(): ReadingPositions =
    new(result, delete)
    result.setup

  proc getRecord*(self: ReadingPositions, threadId: string): string {.slot.} =
    result = self.records.getOrDefault(threadId)

  proc setRecord*(self: ReadingPositions, threadId: string, record: string) {.slot.} =
    if record.len == 0:
      self.records.del(threadId)
      return
    self.records[threadId] = record

  proc setJump*(self: ReadingPositions, messageId: string) =
    self.jump = messageId

  proc takeJump*(self: ReadingPositions): string {.slot.} =
    result = self.jump
    self.jump = ""

  proc setup(self: ReadingPositions) =
    self.QObject.setup

  proc delete*(self: ReadingPositions) =
    self.QObject.delete
