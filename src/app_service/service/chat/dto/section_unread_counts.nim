import std/[json, tables]

const PERSONAL_SECTION_ID* = "personal"

type SectionUnreadCounts* = object
  unviewedMessagesCount*: int
  unviewedMentionsCount*: int

proc parseSectionUnreadCounts*(response: JsonNode): Table[string, SectionUnreadCounts] =
  if response.isNil or response.kind != JObject or not response.hasKey("sections") or
      response["sections"].kind != JArray:
    raise newException(ValueError, "section unread counts response is missing sections")
  for section in response["sections"]:
    if section.kind != JObject or not section.hasKey("sectionId") or
        section["sectionId"].kind != JString or section["sectionId"].getStr.len == 0:
      raise newException(ValueError, "section unread counts entry is missing sectionId")
    let sectionId = section["sectionId"].getStr
    if result.hasKey(sectionId):
      raise newException(ValueError, "duplicate section unread counts entry: " & sectionId)
    for field in ["unviewedMessagesCount", "unviewedMentionsCount"]:
      if not section.hasKey(field) or section[field].kind != JInt or
          section[field].getBiggestInt < 0 or section[field].getBiggestInt > BiggestInt(high(int)):
        raise newException(ValueError, "invalid section unread count: " & field)
    result[sectionId] = SectionUnreadCounts(
      unviewedMessagesCount: section["unviewedMessagesCount"].getInt,
      unviewedMentionsCount: section["unviewedMentionsCount"].getInt)
  if not result.hasKey(PERSONAL_SECTION_ID):
    raise newException(ValueError, "section unread counts response is missing personal section")
