import tables
import ../contacts/dto/contacts
import ../contacts/dto/contact_details

proc hasOwnName*(contact: ContactsDto): bool =
  contact.added or contact.localNickname.len > 0 or contact.displayName.len > 0 or
    (contact.ensVerified and contact.name.len > 0)

type MentionSelf* = object
  pubKey*: string
  name*: string

proc mentionDisplayName*(cached: ptr ContactDetails, mentionedNames: Table[string, string],
    pubKey: string, generateAlias: proc(pubKey: string): string, me = MentionSelf()): string =
  ## The live own-profile name for self, then a cached contact with a name of its own,
  ## then the name from status-go, then the alias. Never adds to the contacts cache.
  if me.pubKey.len > 0 and pubKey == me.pubKey and me.name.len > 0:
    return me.name
  if not cached.isNil and cached[].dto.hasOwnName():
    return cached[].dto.userDefaultDisplayName()
  let name = mentionedNames.getOrDefault(pubKey)
  if name.len > 0:
    return name
  if not cached.isNil and cached[].dto.alias.len > 0:
    return cached[].dto.alias
  generateAlias(pubKey)
