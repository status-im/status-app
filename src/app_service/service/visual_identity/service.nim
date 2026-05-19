import chronicles, marshal

import ./dto as dto
import ../../../backend/visual_identity as status_visual_identity

export dto

proc emojiHashOf*(pubkey: string): EmojiHashDto =
  try:
    let response = status_visual_identity.emojiHashOf(pubkey)
    if not response.error.isNil:
      error "error emojiHashOf: ", errDescription = response.error.message
    result = toEmojiHashDto(response.result)
  except Exception as e:
    error "error: ", procName = "emojiHashOf", errName = e.name, errDesription = e.msg

proc colorIdOf*(pubkey: string): int =
  try:
    let response = status_visual_identity.colorIdOf(pubkey)
    if not response.error.isNil:
      error "error colorIdOf: ", errDescription = response.error.message
    result = toColorId(response.result)
  except Exception as e:
    error "error: ", procName = "colorIdOf", errName = e.name, errDesription = e.msg

proc getEmojiHashAsJson*(publicKey: string): string =
  return $$ emojiHashOf(publicKey)
