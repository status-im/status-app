import io_interface

import ../../../../app_service/service/gif/service as gif_service
import ../../../../app_service/service/gif/dto
import ../../../core/eventemitter
import ../../../core/unique_event_emitter

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: UniqueUUIDEventEmitter
    gifService: gif_service.Service

proc newController*(
    delegate: io_interface.AccessInterface,
    events: EventEmitter,
    gifService: gif_service.Service,
    ): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = initUniqueUUIDEventEmitter(events)
  result.gifService = gifService

proc delete*(self: Controller) =
  self.events.disconnect()

proc init*(self: Controller) =
  self.events.on(SIGNAL_LOAD_RECENT_GIFS_DONE) do(e:Args):
    let args = GifsArgs(e)
    self.delegate.loadRecentGifsDone(args.gifs)

  self.events.on(SIGNAL_LOAD_FAVORITE_GIFS_DONE) do(e:Args):
    let args = GifsArgs(e)
    self.delegate.loadFavoriteGifsDone(args.gifs)

  self.events.on(SIGNAL_LOAD_TRENDING_GIFS_STARTED) do(e:Args):
    self.delegate.loadTrendingGifsStarted()

  self.events.on(SIGNAL_LOAD_TRENDING_GIFS_DONE) do(e:Args):
    let args = GifsArgs(e)
    self.delegate.loadTrendingGifsDone(args.gifs)

  self.events.on(SIGNAL_LOAD_TRENDING_GIFS_ERROR) do(e:Args):
    self.delegate.loadTrendingGifsError()

  self.events.on(SIGNAL_SEARCH_GIFS_STARTED) do(e:Args):
    self.delegate.searchGifsStarted()

  self.events.on(SIGNAL_SEARCH_GIFS_DONE) do(e:Args):
    let args = GifsArgs(e)
    self.delegate.searchGifsDone(args.gifs)

  self.events.on(SIGNAL_SEARCH_GIFS_ERROR) do(e:Args):
    self.delegate.searchGifsError()

proc searchGifs*(self: Controller, query: string) =
  self.gifService.search(query)

proc getTrendingsGifs*(self: Controller) =
  self.gifService.getTrending()

proc getRecentsGifs*(self: Controller): seq[GifDto] =
  return self.gifService.getRecents()

proc loadRecentGifs*(self: Controller) =
  self.gifService.asyncLoadRecentGifs()

proc loadFavoriteGifs*(self: Controller) =
  self.gifService.asyncLoadFavoriteGifs()

proc getFavoritesGifs*(self: Controller): seq[GifDto] =
  return self.gifService.getFavorites()

proc toggleFavoriteGif*(self: Controller, item: GifDto) =
  self.gifService.toggleFavorite(item)

proc addToRecentsGif*(self: Controller, item: GifDto) =
  self.gifService.addToRecents(item)

proc isFavorite*(self: Controller, item: GifDto): bool =
  return self.gifService.isFavorite(item)
