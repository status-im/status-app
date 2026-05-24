import json, strutils

import ../../../backend/preferences

type
  Service* = ref object of RootObj

proc delete*(self: Service) =
  discard

proc newService*(): Service =
  Service()

proc put*(_: Service, category, key, value: string): bool =
  if category.isEmptyOrWhitespace or key.isEmptyOrWhitespace:
    return false

  let response = preferences.set(category, key, value)
  if response.error != nil:
    return false
  true

proc get*(_: Service, category, key: string): string =
  if category.isEmptyOrWhitespace or key.isEmptyOrWhitespace:
    return ""

  let response = preferences.get(category, key)
  if response.error != nil:
    return ""
  if not response.result{"found"}.getBool():
    return ""
  response.result{"value"}.getStr()

proc purgeCategory*(_: Service, category: string, validKeys: seq[string]): bool =
  if category.isEmptyOrWhitespace:
    return false

  var filteredKeys: seq[string] = @[]
  for key in validKeys:
    if not key.isEmptyOrWhitespace:
      filteredKeys.add(key)

  try:
    if filteredKeys.len == 0:
      let response = preferences.deleteCategory(category)
      return response.error == nil

    let response = preferences.purgeUnknown(category, filteredKeys)
    response.error == nil
  except CatchableError:
    false
