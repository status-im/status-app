import std/strformat
import json_serialization

type MarketItem* = ref object of RootObj
    key*                      {.serializedFieldName("id").}: string
    symbol*                   {.serializedFieldName("symbol").}: string
    name*                     {.serializedFieldName("name").}: string
    image*                    {.serializedFieldName("image").}: string
    currentPrice*             {.serializedFieldName("current_price").}: float64
    marketCap*                {.serializedFieldName("market_cap").}: float64
    totalVolume*              {.serializedFieldName("total_volume").}: float64
    priceChangePercentage24h* {.serializedFieldName("price_change_percentage_24h").}: float64

proc `$`*(self: MarketItem): string =
  result = fmt"""MarketItem[
    key: {self.key},
    name: {self.name},
    symbol: {self.symbol},
    image: {self.image},
    currentPrice: {self.currentPrice},
    marketCap: {self.marketCap},
    totalVolume: {self.totalVolume},
    priceChangePercentage24h: {self.priceChangePercentage24h},
    ]"""

type LeaderboardPage* = ref object of RootObj
    totalCount* {.serializedFieldName("all_cryptocurrency_count").}: int
    page*       {.serializedFieldName("page").}: int
    pageSize*   {.serializedFieldName("page_size").}: int
    sortOrder*  {.serializedFieldName("sorting").}: int
    currency*   {.serializedFieldName("currency").}: string
    data*       {.serializedFieldName("cryptocurrencies").}: seq[MarketItem]

proc `$`*(self: LeaderboardPage): string =
  result = fmt"""LeaderboardPage[
    totalCount: {self.totalCount},
    page: {self.page},
    pageSize: {self.pageSize},
    sortOrder: {self.sortOrder},
    currency: {self.currency},
    data: {self.data}
    ]"""

# PriceData represents price data update
type PriceData* = ref object of RootObj
  id*                 {.serializedFieldName("id").}: string
  price*              {.serializedFieldName("current_price").}: float64
  percentChange24h*   {.serializedFieldName("price_change_percentage_24h").}: float64

proc `$`*(self: PriceData): string =
  result = fmt"""PriceData[
    id: {self.id},
    price: {self.price},
    percentChange24h: {self.percentChange24h}
    ]"""

type LeaderboardPagePrices* = ref object of RootObj
  page*         {.serializedFieldName("page").}: int
  pageSize*     {.serializedFieldName("page_size").}: int
  sortOrder*    {.serializedFieldName("sorting").}: int
  currency*     {.serializedFieldName("currency").}: string
  data*         {.serializedFieldName("prices").}: seq[PriceData]

proc `$`*(self: LeaderboardPagePrices): string =
  result = fmt"""LeaderboardPagePrices[
    page: {self.page},
    pageSize: {self.pageSize},
    sortOrder: {self.sortOrder},
    currency: {self.currency},
    data: {self.data}
    ]"""

proc diff* (a: MarketItem, b: var MarketItem): tuple[isEqual:bool, changedFields: seq[string]] =
  result.isEqual = true
  result.changedFields = @[]

  if a.key != b.key:
    result.isEqual = false
    b.key = a.key
    result.changedFields.add("key")

  if a.name != b.name:
    result.isEqual = false
    b.name = a.name
    result.changedFields.add("name")

  if a.symbol != b.symbol:
    result.isEqual = false
    b.symbol = a.symbol
    result.changedFields.add("symbol")

  if a.image != b.image:
    result.isEqual = false
    b.image = a.image
    result.changedFields.add("image")

  if a.currentPrice != b.currentPrice:
    result.isEqual = false
    b.currentPrice = a.currentPrice
    result.changedFields.add("currentPrice")

  if a.marketCap != b.marketCap:
    result.isEqual = false
    b.marketCap = a.marketCap
    result.changedFields.add("marketCap")

  if a.totalVolume != b.totalVolume:
    result.isEqual = false
    b.totalVolume = a.totalVolume
    result.changedFields.add("totalVolume")

  if a.priceChangePercentage24h != b.priceChangePercentage24h:
    result.isEqual = false
    b.priceChangePercentage24h = a.priceChangePercentage24h
    result.changedFields.add("priceChangePercentage24h")

proc pricesDiff* (a: PriceData, b: var MarketItem): tuple[isEqual:bool, changedFields: seq[string]] =
  result.isEqual = true
  result.changedFields = @[]

  if a.price != b.currentPrice:
    result.isEqual = false
    b.currentPrice = a.price
    result.changedFields.add("currentPrice")

  if a.percentChange24h != b.priceChangePercentage24h:
    result.isEqual = false
    b.priceChangePercentage24h = a.percentChange24h
    result.changedFields.add("priceChangePercentage24h")
