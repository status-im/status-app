proc getTokensMarketValuesLoading*(self: Service): bool =
  return self.tokensPricesLoading or self.tokensMarketDetailsLoading

# resolveTokensMarketValuesLoadingStateAndNotify ensures that only a single signal is emitted when:
# - either tokens prices or tokens market details are about to be updated
# - tokens prices and tokens market details are updated (when both are loaded)
proc resolveTokensMarketValuesLoadingStateAndNotify(self: Service, tokensPricesLoading: bool, tokensMarketDetailsLoading: bool) =
  if not self.getTokensMarketValuesLoading():
    self.tokensPricesLoading = tokensPricesLoading
    self.tokensMarketDetailsLoading = tokensMarketDetailsLoading
    if self.getTokensMarketValuesLoading():
      self.events.emit(SIGNAL_TOKENS_MARKET_VALUES_ABOUT_TO_BE_UPDATED, Args())
    return
  self.tokensPricesLoading = tokensPricesLoading
  self.tokensMarketDetailsLoading = tokensMarketDetailsLoading
  if not self.getTokensMarketValuesLoading():
    self.events.emit(SIGNAL_TOKENS_MARKET_VALUES_UPDATED, Args())

proc setTokensMarketDetailsLoadingStateAndNotify(self: Service, state: bool) =
  self.resolveTokensMarketValuesLoadingStateAndNotify(self.tokensPricesLoading, state)

proc setTokensPricesLoadingStateAndNotify(self: Service, state: bool) =
  self.resolveTokensMarketValuesLoadingStateAndNotify(state, self.tokensMarketDetailsLoading)

proc updateTokenPrices*(self: Service, updatedPrices: Table[string, float64]) =
  var anyUpdated = false
  for tokenKey, price in updatedPrices:
    if not self.tokenPriceTable.hasKey(tokenKey) or self.tokenPriceTable[tokenKey] != price:
      anyUpdated = true
      self.tokenPriceTable[tokenKey] = price
  if anyUpdated:
    self.events.emit(SIGNAL_TOKENS_MARKET_VALUES_UPDATED, Args())

# if tokensKeys is empty, market values for all tokens will be fetched
proc fetchTokensMarketValues(self: Service, tokensKeys: seq[string] = @[]) =
  defer: self.setTokensMarketDetailsLoadingStateAndNotify(true)
  let arg = FetchTokensMarketValuesTaskArg(
    tptr: fetchTokensMarketValuesTask,
    vptr: cast[uint](self.vptr),
    slot: "tokensMarketValuesRetrieved",
    tokensKeys: tokensKeys,
    currency: self.getCurrency()
  )
  self.threadpool.start(arg)

proc tokensMarketValuesRetrieved(self: Service, response: string) {.slot.} =
  # this is emited so that the models can notify about market values being available
  defer: self.setTokensMarketDetailsLoadingStateAndNotify(false)
  try:
    let env = Json.decode(response, TokensMarketValuesSlotResponse, allowUnknownFields = true)
    if not env.error.isEmptyOrWhitespace:
      raise newException(Exception, "Error getting tokens market values: " & env.error)
    if env.tokenMarketValues.isNil or env.tokenMarketValues.kind == JNull:
      return
    var tokensResult: JsonNode
    discard env.tokenMarketValues.getProp("result", tokensResult)
    if tokensResult.isNil or tokensResult.kind == JNull:
      return

    for (tokenKey, marketValuesObj) in tokensResult.pairs:
      let marketValuesDto = Json.decode($marketValuesObj, TokenMarketValuesDto, allowUnknownFields = true)
      self.tokenMarketValuesTable[tokenKey] = TokenMarketValuesItem(
        marketCap: marketValuesDto.marketCap,
        highDay: marketValuesDto.highDay,
        lowDay: marketValuesDto.lowDay,
        changePctHour: marketValuesDto.changePctHour,
        changePctDay: marketValuesDto.changePctDay,
        changePct24hour: marketValuesDto.changePct24hour,
        change24hour: marketValuesDto.change24hour)
    self.hasMarketDetailsCache = true
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription

# if tokensKeys is empty, details for all tokens will be fetched
proc fetchTokensDetails(self: Service, tokensKeys: seq[string] = @[]) =
  self.tokensDetailsLoading = true
  let arg = FetchTokensDetailsTaskArg(
    tptr: fetchTokensDetailsTask,
    vptr: cast[uint](self.vptr),
    slot: "tokensDetailsRetrieved",
    tokensKeys: tokensKeys
  )
  self.threadpool.start(arg)

proc tokensDetailsRetrieved(self: Service, response: string) {.slot.} =
  self.tokensDetailsLoading = false
  # this is emited so that the models can notify about details being available
  defer: self.events.emit(SIGNAL_TOKENS_DETAILS_UPDATED, Args())
  try:
    let env = Json.decode(response, TokensDetailsSlotResponse, allowUnknownFields = true)
    if not env.error.isEmptyOrWhitespace:
      raise newException(Exception, "Error getting tokens details: " & env.error)
    if env.tokensDetails.isNil or env.tokensDetails.kind == JNull:
      return
    var tokensResult: JsonNode
    discard env.tokensDetails.getProp("result", tokensResult)
    if tokensResult.isNil or tokensResult.kind == JNull:
      return

    for (tokenKey, tokenDetailsObj) in tokensResult.pairs:
      let tokenDetailsDto = Json.decode($tokenDetailsObj, TokenDetailsDto, allowUnknownFields = true)
      self.tokenDetailsTable[tokenKey] = TokenDetailsItem(
        description: tokenDetailsDto.description,
        assetWebsiteUrl: tokenDetailsDto.assetWebsiteUrl)
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription

# if tokensKeys is empty, prices for all tokens will be fetched
proc fetchTokensPrices(self: Service, tokensKeys: seq[string] = @[]) =
  defer: self.setTokensPricesLoadingStateAndNotify(true)
  let arg = FetchTokensPricesTaskArg(
    tptr: fetchTokensPricesTask,
    vptr: cast[uint](self.vptr),
    slot: "tokensPricesRetrieved",
    tokensKeys: tokensKeys,
    currencies: @[self.getCurrency()]
  )
  self.threadpool.start(arg)

proc tokensPricesRetrieved(self: Service, response: string) {.slot.} =
  # this is emited so that the models can notify about prices being available
  defer: self.setTokensPricesLoadingStateAndNotify(false)
  try:
    let env = Json.decode(response, TokensPricesSlotResponse, allowUnknownFields = true)
    if not env.error.isEmptyOrWhitespace:
      raise newException(Exception, "Error getting tokens prices: " & env.error)
    if env.tokensPrices.isNil or env.tokensPrices.kind == JNull:
      return
    var tokensResult: JsonNode
    discard env.tokensPrices.getProp("result", tokensResult)
    if tokensResult.isNil or tokensResult.kind == JNull:
      return

    for (tokenKey, prices) in tokensResult.pairs:
      for (currency, price) in prices.pairs:
        if cmpIgnoreCase(self.getCurrency(), currency) == 0:
          self.tokenPriceTable[tokenKey] = price.getFloat
    self.hasPriceValuesCache = true
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription

# History Data
proc tokenHistoricalDataResolved*(self: Service, response: string) {.slot.} =
  let responseObj = response.parseJson
  if (responseObj.kind != JObject):
    info "prepared tokens are not a json object"
    return

  self.events.emit(SIGNAL_TOKEN_HISTORICAL_DATA_LOADED, TokenHistoricalDataArgs(
    result: response
  ))

proc getHistoricalDataForToken*(self: Service, tokenKey: string, currency: string, range: int) =
  let arg = GetTokenHistoricalDataTaskArg(
    tptr: getTokenHistoricalDataTask,
    vptr: cast[uint](self.vptr),
    slot: "tokenHistoricalDataResolved",
    tokenKey: tokenKey,
    currency: currency,
    range: range
  )
  self.threadpool.start(arg)