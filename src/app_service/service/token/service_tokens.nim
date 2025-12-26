proc getMandatoryTokenKeys(): seq[string] =
  try:
    var response: JsonNode
    var err = status_go_tokens.getMandatoryTokenKeys(response)
    if err.len > 0:
      raise newException(CatchableError, "failed" & err)
    if response.isNil or response.kind != JsonNodeKind.JArray:
      raise newException(CatchableError, "unexpected response")

    # Create a copy of the tokenResultStr to avoid exceptions in `decode`
    # Workaround for https://github.com/status-im/status-desktop/issues/17398
    let responseStr = $response
    let parsedResponse = Json.decode(responseStr, seq[string], allowUnknownFields = true)
    result = parsedResponse
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription

proc tokenAvailableForBridgingViaHop(tokenChainId: int, tokenAddress: string): bool =
  try:
    var response: JsonNode
    var err = status_go_tokens.tokenAvailableForBridgingViaHop(response, tokenChainId, tokenAddress)
    if err.len > 0:
      raise newException(CatchableError, "failed" & err)
    if response.isNil or response.kind != JsonNodeKind.JBool:
      raise newException(CatchableError, "unexpected response")
    result = response.getBool()
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription

proc getListOfTokenKeysAvailableForSwapViaParaswap(chainId: int): seq[string] =
  try:
    var response: JsonNode
    var err = status_go_tokens.getListOfTokenKeysAvailableForSwapViaParaswap(response, chainId)
    if err.len > 0:
      raise newException(CatchableError, "failed" & err)
    if response.isNil or response.kind != JsonNodeKind.JArray:
      raise newException(CatchableError, "unexpected response")
    # Create a copy of the tokenResultStr to avoid exceptions in `decode`
    # Workaround for https://github.com/status-im/status-desktop/issues/17398
    let responseStr = $response
    let parsedResponse = Json.decode(responseStr, seq[string], allowUnknownFields = true)
    result = parsedResponse
  except Exception as e:
    let errDesription = e.msg
    error "error1: ", errDesription

proc getAllTokenLists(): seq[TokenListItem] =
  try:
    var response: JsonNode
    var err = status_go_tokens.getAllTokenLists(response)
    if err.len > 0:
      raise newException(CatchableError, "failed" & err)
    if response.isNil or response.kind != JsonNodeKind.JArray:
      raise newException(CatchableError, "unexpected response")

    # Create a copy of the tokenResultStr to avoid exceptions in `decode`
    # Workaround for https://github.com/status-im/status-desktop/issues/17398
    let responseStr = $response
    let parsedResponse = Json.decode(responseStr, seq[TokenListDto], allowUnknownFields = true)
    result = parsedResponse.map(tl => createTokenListItem(tl))
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription

proc getAllTokens(): seq[TokenItem] =
  try:
    var response: JsonNode
    var err = status_go_tokens.getAllTokens(response)
    if err.len > 0:
      raise newException(CatchableError, "failed" & err)
    if response.isNil or response.kind != JsonNodeKind.JArray:
      raise newException(CatchableError, "unexpected response")

    # Create a copy of the tokenResultStr to avoid exceptions in `decode`
    # Workaround for https://github.com/status-im/status-desktop/issues/17398
    let responseStr = $response
    let parsedResponse = Json.decode(responseStr, seq[TokenDto], allowUnknownFields = true)
    result = parsedResponse.map(t => createTokenItem(t))
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription

proc getTokensOfInterestForActiveNetworksMode(): seq[TokenItem] =
  try:
    var response: JsonNode
    var err = status_go_tokens.getTokensOfInterestForActiveNetworksMode(response)
    if err.len > 0:
      raise newException(CatchableError, "failed" & err)
    if response.isNil or response.kind != JsonNodeKind.JArray:
      raise newException(CatchableError, "unexpected response")

    # Create a copy of the tokenResultStr to avoid exceptions in `decode`
    # Workaround for https://github.com/status-im/status-desktop/issues/17398
    let responseStr = $response
    let parsedResponse = Json.decode(responseStr, seq[TokenDtoSafe], allowUnknownFields = true)
    result = parsedResponse.map(t => createTokenItem(t))
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription


proc getTokensForActiveNetworksMode(): seq[TokenItem] =
  try:
    var response: JsonNode
    var err = status_go_tokens.getTokensForActiveNetworksMode(response)
    if err.len > 0:
      raise newException(CatchableError, "failed" & err)
    if response.isNil or response.kind != JsonNodeKind.JArray:
      raise newException(CatchableError, "unexpected response")

    # Create a copy of the tokenResultStr to avoid exceptions in `decode`
    # Workaround for https://github.com/status-im/status-desktop/issues/17398
    let responseStr = $response
    let parsedResponse = Json.decode(responseStr, seq[TokenDtoSafe], allowUnknownFields = true)
    result = parsedResponse.map(t => createTokenItem(t))
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription


proc getTokenByChainAddress(chainId: int, address: string): TokenItem =
  try:
    var response: JsonNode
    var err = status_go_tokens.getTokenByChainAddress(response, chainId, address)
    if err.len > 0:
      raise newException(CatchableError, "failed" & err)
    if response.isNil or response.kind != JsonNodeKind.JObject:
      raise newException(CatchableError, "unexpected response")

    # Create a copy of the tokenResultStr to avoid exceptions in `decode`
    # Workaround for https://github.com/status-im/status-desktop/issues/17398
    let responseStr = $response
    let parsedResponse = Json.decode(responseStr, TokenDto, allowUnknownFields = true)
    result = createTokenItem(parsedResponse)
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription


proc getTokensByChain(chainId: int): seq[TokenItem] =
  try:
    var response: JsonNode
    var err = status_go_tokens.getTokensByChain(response, chainId)
    if err.len > 0:
      raise newException(CatchableError, "failed" & err)
    if response.isNil or response.kind != JsonNodeKind.JArray:
      raise newException(CatchableError, "unexpected response")

    # Create a copy of the tokenResultStr to avoid exceptions in `decode`
    # Workaround for https://github.com/status-im/status-desktop/issues/17398
    let responseStr = $response
    let parsedResponse = Json.decode(responseStr, seq[TokenDtoSafe], allowUnknownFields = true)
    result = parsedResponse.map(t => createTokenItem(t))
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription


proc getTokensByKeys(keys: seq[string]): seq[TokenItem] =
  try:
    var response: JsonNode
    var err = status_go_tokens.getTokensByKeys(response, keys)
    if err.len > 0:
      raise newException(CatchableError, "failed" & err)
    if response.isNil or response.kind != JsonNodeKind.JArray:
      raise newException(CatchableError, "unexpected response")

    # Create a copy of the tokenResultStr to avoid exceptions in `decode`
    # Workaround for https://github.com/status-im/status-desktop/issues/17398
    let responseStr = $response
    let parsedResponse = Json.decode(responseStr, seq[TokenDtoSafe], allowUnknownFields = true)
    result = parsedResponse.map(t => createTokenItem(t))
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription