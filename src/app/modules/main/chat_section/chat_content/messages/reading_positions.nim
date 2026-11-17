import nimqml, tables

# Where the reader was in the chat and in each of its threads (by thread id,
# "" for the chat itself), as recorded by the messages view, so that it
# outlives the view
QtObject:
  type
    ReadingPositions* = ref object of QObject
      records: Table[string, string]

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

  proc setup(self: ReadingPositions) =
    self.QObject.setup

  proc delete*(self: ReadingPositions) =
    self.QObject.delete
