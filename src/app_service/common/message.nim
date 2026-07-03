import sequtils, strutils, sugar, regex
import ../service/contacts/dto/contacts
from conversion import SystemTagMapping


proc replaceMentionsWithPubKeys*(allKnownContacts: seq[ContactsDto], message: string): string =
  const aliasPattern = re2(r"(@[A-z][a-z]+ [A-z][a-z]* [A-z][a-z]*)", flags = {regexCaseless})
  const ensPattern = re2(r"(@\w+((\.stateofus)?\.eth))", flags = {regexCaseless})
  const namePattern = re2(r"(@\w+)", flags = {regexCaseless})

  var aliasMentions = newSeq[string]()
  for m in findAll(message, aliasPattern):
    aliasMentions.add message[m.boundaries]
  var ensMentions = newSeq[string]()
  for m in findAll(message, ensPattern):
    ensMentions.add message[m.boundaries]
  var nameMentions = newSeq[string]()
  for m in findAll(message, namePattern):
    nameMentions.add message[m.boundaries]
  var updatedMessage = message

  # replace system tag with system ID
  for pair in SystemTagMapping:
    updatedMessage = updatedMessage.replaceWord(pair[0], pair[1])

  # In the following lines we're free to compare to `x.userDefaultDisplayName()` cause that's actually what we're displaying
  # in the mentions suggestion list.
  for mention in aliasMentions:
    let mention = mention # TODO https://github.com/nim-lang/Nim/issues/16740
    let listOfMatched = allKnownContacts.filter(x => "@" & x.userDefaultDisplayName().toLowerAscii == mention.toLowerAscii)
    if(listOfMatched.len > 0):
      updatedMessage = updatedMessage.replaceWord(mention, '@' & listOfMatched[0].id)

  for mention in ensMentions:
    let mention = mention # TODO https://github.com/nim-lang/Nim/issues/16740
    let listOfMatched = allKnownContacts.filter(x => "@" & x.name.toLowerAscii == mention.toLowerAscii)
    if(listOfMatched.len > 0):
      updatedMessage = updatedMessage.replaceWord(mention, '@' & listOfMatched[0].id)

  for mention in nameMentions:
    let mention = mention # TODO https://github.com/nim-lang/Nim/issues/16740
    let listOfMatched = allKnownContacts.filter(x => x.userDefaultDisplayName().toLowerAscii == mention.toLowerAscii or
      "@" & x.userDefaultDisplayName().toLowerAscii == mention.toLowerAscii)
    if(listOfMatched.len > 0):
      updatedMessage = updatedMessage.replaceWord(mention, '@' & listOfMatched[0].id)
  return updatedMessage
