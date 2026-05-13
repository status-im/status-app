include app_service/common/mnemonics

proc generateRandomPUK*(): string =
  randomize()
  for i in 0 ..< PUKLengthForStatusApp:
    result = result & $rand(0 .. 9)

proc buildSeedPhrasesFromIndexes*(seedPhraseIndexes: JsonNode): seq[string] =
  var seedPhrase: seq[string]
  for ind in seedPhraseIndexes.items:
    seedPhrase.add(englishWords[ind.getInt])
  return seedPhrase

proc pairingJsonEntryIsValid(pairing: JsonNode): bool =
  if pairing.isNil or pairing.kind != JObject:
    return false
  let keyHex = pairing{"key"}.getStr("")
  let index = pairing{"index"}.getInt(-1)
  return keyHex.len > 0 and index >= 0

proc findPairingJsonForInstance(pairingsRoot: JsonNode, keycardUid: string): JsonNode =
  if pairingsRoot.isNil or pairingsRoot.kind != JObject or keycardUid.len == 0:
    return nil
  if pairingsRoot.hasKey(keycardUid):
    return pairingsRoot[keycardUid]
  for k, v in pairingsRoot.pairs:
    if cmpIgnoreCase(k, keycardUid) == 0:
      return v
  return nil

proc keycardPairingExists*(keycardUid: string): bool =
  if keycardUid.len == 0:
    return false
  let path = KEYCARDPAIRINGDATAFILE
  if not fileExists(path):
    return false
  var data: string
  try:
    data = readFile(path)
  except CatchableError:
    return false
  if data.len == 0:
    return false
  var doc: JsonNode
  try:
    doc = parseJson(data)
  except CatchableError:
    return false
  if doc.kind != JObject:
    return false
  let entry = findPairingJsonForInstance(doc, keycardUid)
  return pairingJsonEntryIsValid(entry)