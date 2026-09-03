import ../../../../app_service/service/gif/dto

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method searchGifs*(self: AccessInterface, query: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getTrendingsGifs*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getRecentsGifs*(self: AccessInterface): seq[GifDto] {.base.} =
  raise newException(ValueError, "No implementation available")

method loadRecentGifs*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadRecentGifsDone*(self: AccessInterface, gifs: seq[GifDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadTrendingGifsStarted*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadTrendingGifsError*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadTrendingGifsDone*(self: AccessInterface, gifs: seq[GifDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method searchGifsStarted*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method searchGifsError*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method searchGifsDone*(self: AccessInterface, gifs: seq[GifDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method getFavoritesGifs*(self: AccessInterface): seq[GifDto] {.base.} =
  raise newException(ValueError, "No implementation available")

method loadFavoriteGifs*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadFavoriteGifsDone*(self: AccessInterface, gifs: seq[GifDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleFavoriteGif*(self: AccessInterface, item: GifDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method addToRecentsGif*(self: AccessInterface, item: GifDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method isFavorite*(self: AccessInterface, item: GifDto): bool {.base.} =
  raise newException(ValueError, "No implementation available")
