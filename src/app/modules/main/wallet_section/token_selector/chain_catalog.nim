## The swap receive picker's catalog: the token groups of one chain, read from
## that chain's shared model. The model exists only while the chain is held, so
## it is looked up by chain on every read.

import app/modules/shared_models/token_selector_model
import app_service/service/token/items/token_group
import ../all_tokens/token_groups_model

type
  ChainCatalog* = ref object
    chainId: int
    models: proc(chainId: int): TokenGroupsModel

proc newChainCatalog*(models: proc(chainId: int): TokenGroupsModel): ChainCatalog =
  ChainCatalog(chainId: -1, models: models)

proc setChain*(self: ChainCatalog, chainId: int): bool =
  ## Whether the chain changed, so the picker must recompute.
  if chainId == self.chainId:
    return false
  self.chainId = chainId
  true

proc reads*(self: ChainCatalog, chainId: int): bool =
  chainId > 0 and chainId == self.chainId

proc model(self: ChainCatalog): TokenGroupsModel =
  ## nil while the chain is not held
  if self.chainId <= 0:
    return nil
  self.models(self.chainId)

proc wire*(self: ChainCatalog, source: var TokenSelectorSource, search: TokenGroupsModel,
    toPopular: proc(groups: seq[TokenGroupItem]): seq[PopularGroup]) =
  ## The popular rows and the lazy loading of the chain's model, or of the
  ## search model while searching.
  let catalog = self
  source.getPopular = proc(): seq[PopularGroup] =
    let model = catalog.model()
    if model.isNil: @[] else: toPopular(model.getLoadedGroups())
  source.pinGroup = proc(key: string): bool =
    let model = catalog.model()
    not model.isNil and model.ensureKeyLoaded(key)
  source.fetchMore = proc(searching: bool) =
    if searching:
      search.fetchMore()
      return
    let model = catalog.model()
    if not model.isNil:
      model.fetchMore()
  source.hasMore = proc(searching: bool): bool =
    if searching:
      return search.hasMoreItemsForSource()
    let model = catalog.model()
    not model.isNil and model.hasMoreItemsForSource()
  source.isLoadingMore = proc(searching: bool): bool =
    if searching:
      return search.isLoadingMoreForSource()
    let model = catalog.model()
    not model.isNil and model.isLoadingMoreForSource()
