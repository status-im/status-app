## The communities token list: the wallet's rows are replaced as a whole (and
## all go when the all-token-groups copy is dropped), while rows the communities
## added stay. Compile with -d:QT_MODEL_SPY (needs the seaqt/nimqml toolchain).

import unittest, sequtils, sets

import app/modules/shared_models/token_list_model
import app/modules/shared_models/token_list_item

proc row(key: string, category: TokenListItemCategory, communityId = ""): TokenListItem =
  initTokenListItem(key = key, name = key, symbol = key, color = "", image = "",
    category = ord(category), communityId = communityId, decimals = 18, privilegesLevel = 0)

proc keys(model: TokenListModel): seq[string] =
  model.items.mapIt(it.key)

suite "communities token list":

  test "dropping the wallet rows keeps the community rows":
    let model = newTokenListModel()
    model.addItems(@[row("minted", TokenListItemCategory.Community, "c1")])
    model.setWalletTokenItems(@[
      row("eth", TokenListItemCategory.General),
      # a wallet row for a community-issued token
      row("ctok", TokenListItemCategory.General, "c2"),
    ])
    check model.keys == @["eth", "ctok", "minted"]
    model.setWalletTokenItems(@[])
    check model.keys == @["minted"]

  test "setting the wallet rows again replaces them":
    let model = newTokenListModel()
    model.addItems(@[row("minted", TokenListItemCategory.Community, "c1")])
    let wallet = @[row("eth", TokenListItemCategory.General), row("ctok", TokenListItemCategory.General, "c2")]
    model.setWalletTokenItems(wallet)
    model.setWalletTokenItems(wallet)
    check model.keys == @["eth", "ctok", "minted"]

  test "a community row re-added after a drop is not listed twice after the reload":
    let model = newTokenListModel()
    let communityRow = row("ctok", TokenListItemCategory.Community, "c2")
    let wallet = @[row("eth", TokenListItemCategory.General), row("ctok", TokenListItemCategory.General, "c2")]
    model.setWalletTokenItems(wallet)
    model.addUnlistedItems(@[communityRow])
    check model.keys == @["eth", "ctok"]
    # drop, then the communities rebuild brings the community's own row back
    model.setWalletTokenItems(@[])
    model.addUnlistedItems(@[communityRow])
    check model.items.mapIt(it.category) == @[ord(TokenListItemCategory.Community)]
    model.setWalletTokenItems(wallet)
    check model.items.mapIt((it.symbol, it.communityId)) == @[("eth", ""), ("ctok", "c2")]
    check model.items.mapIt(it.category) == @[ord(TokenListItemCategory.General), ord(TokenListItemCategory.General)]

  test "communities built before the wallet rows load are not listed twice":
    let model = newTokenListModel()
    model.addUnlistedItems(@[row("ctok", TokenListItemCategory.Community, "c2"),
      row("minted", TokenListItemCategory.Community, "c1")])
    model.setWalletTokenItems(@[row("ctok", TokenListItemCategory.General, "c2")])
    check model.items.mapIt((it.symbol, it.communityId)) == @[("ctok", "c2"), ("minted", "c1")]

  test "a community row whose wallet row goes on a network change is listed again":
    let model = newTokenListModel()
    let communityRow = row("ctok", TokenListItemCategory.Community, "c2")
    model.setWalletTokenItems(@[row("eth", TokenListItemCategory.General),
      row("ctok", TokenListItemCategory.General, "c2")])
    model.addUnlistedItems(@[communityRow])
    # the network holding ctok is turned off: its wallet row goes, then the
    # communities' rows are added again
    model.setWalletTokenItems(@[row("eth", TokenListItemCategory.General)])
    model.addUnlistedItems(@[communityRow])
    check model.items.mapIt((it.symbol, it.communityId)) == @[("eth", ""), ("ctok", "c2")]
    check model.items.mapIt(it.category) == @[ord(TokenListItemCategory.General), ord(TokenListItemCategory.Community)]

  test "replacing the wallet rows with the same ones drops no community-issued row":
    let model = newTokenListModel()
    let wallet = @[row("eth", TokenListItemCategory.General), row("ctok", TokenListItemCategory.General, "c2")]
    check model.setWalletTokenItems(wallet).len == 0
    check model.setWalletTokenItems(wallet).len == 0

  test "the community-issued wallet rows that go are returned":
    let model = newTokenListModel()
    model.addItems(@[row("minted", TokenListItemCategory.Community, "c1")])
    model.setWalletTokenItems(@[row("eth", TokenListItemCategory.General),
      row("ctok", TokenListItemCategory.General, "c2"),
      row("kept", TokenListItemCategory.General, "c3"),
      row("other", TokenListItemCategory.General, "c4")])
    let dropped = model.setWalletTokenItems(@[row("kept", TokenListItemCategory.General, "c3")])
    check dropped == toHashSet([("ctok", "c2"), ("other", "c4")])
