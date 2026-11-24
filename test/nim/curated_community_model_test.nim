import std/[sets, tables, unittest]

import app/modules/main/communities/models/[curated_community_model, curated_community_item]
import app/modules/shared/qt_model_spy
import app/modules/shared_models/[token_permissions_model, token_permission_item, token_criteria_item, token_permission_chat_list_item]
import app_service/service/community/dto/community

proc createTestCommunityItem(
    id: string,
    name: string = "Name",
    description: string = "Description",
    available: bool = true,
    icon: string = "icon",
    banner: string = "banner",
    color: string = "#ffffff",
    tags: string = "tag",
    members: int = 10,
    activeMembers: int = 5,
    featured: bool = false,
    amIBanned: bool = false,
    joined: bool = false,
    encrypted: bool = false,
    permissions: seq[TokenPermissionItem] = @[],
  ): CuratedCommunityItem =
  return initCuratedCommunityItem(
    id = id,
    name = name,
    description = description,
    available = available,
    icon = icon,
    banner = banner,
    color = color,
    tags = tags,
    members = members,
    activeMembers = activeMembers,
    featured = featured,
    tokenPermissionsItems = permissions,
    amIBanned = amIBanned,
    joined = joined,
    encrypted = encrypted,
  )

proc createTestPermission(id: string, amount: string = "1", channel: string = "general"): TokenPermissionItem =
  initTokenPermissionItem(
    id = id,
    `type` = 1,
    tokenCriteria = @[initTokenCriteriaItem("SNT", "Status", amount, 18, 1, "", false, initTable[int, string]())],
    chatList = @[initTokenPermissionChatListItem("chat-1", channel)],
    isPrivate = false,
    tokenCriteriaMet = false,
    state = TokenPermissionState.Approved,
  )

suite "curated community model":
  test "add item inserts a new row":
    let model = newCuratedCommunityModel()
    let item = createTestCommunityItem("community-a")

    model.addItem(item)

    check(model.rowCount() == 1)
    check(model.getItemById("community-a").getName() == "Name")

  test "add item updates existing row granularly":
    let model = newCuratedCommunityModel()
    let original = createTestCommunityItem(
      id = "community-a",
      name = "Original",
      description = "Keep description",
      icon = "keep-icon",
      members = 10,
      joined = false,
    )
    let replacement = createTestCommunityItem(
      id = "community-a",
      name = "Updated",
      description = "Keep description",
      icon = "keep-icon",
      members = 42,
      joined = true,
    )

    model.addItem(original)
    let originalPermissionsModel = model.getItemById("community-a").getPermissionsModel()

    model.addItem(replacement)

    let updated = model.getItemById("community-a")
    check(model.rowCount() == 1)
    check(updated.getName() == "Updated")
    check(updated.getMembers() == 42)
    check(updated.getJoined() == true)
    check(updated.getDescription() == "Keep description")
    check(updated.getIcon() == "keep-icon")
    check(updated.getPermissionsModel() == originalPermissionsModel)

  test "adding an item again with the same permissions keeps the permissions model":
    let model = newCuratedCommunityModel()
    model.addItem(createTestCommunityItem("community-a", permissions = @[createTestPermission("p1")]))
    let shown = model.getItemById("community-a").getPermissionsModel()

    model.addItem(createTestCommunityItem("community-a", permissions = @[createTestPermission("p1")]))

    check(model.getItemById("community-a").getPermissionsModel() == shown)
    check(shown.getItems().len == 1)

  test "adding an item again with other permissions replaces the permissions model":
    let model = newCuratedCommunityModel()
    model.addItem(createTestCommunityItem("community-a", permissions = @[createTestPermission("p1")]))
    let shown = model.getItemById("community-a").getPermissionsModel()

    for changed in [
        @[createTestPermission("p1", amount = "2")],
        @[createTestPermission("p1", channel = "random")],
        @[createTestPermission("p2")],
        @[createTestPermission("p1"), createTestPermission("p2")],
        newSeq[TokenPermissionItem]()]:
      let replacement = createTestCommunityItem("community-a", permissions = changed)
      model.addItem(replacement)

      check(model.getItemById("community-a").getPermissionsModel() != shown)
      check(model.getItemById("community-a").getPermissionsModel() == replacement.getPermissionsModel())
      model.addItem(createTestCommunityItem("community-a", permissions = @[createTestPermission("p1")]))

  test "adding the same items again changes no row":
    let model = newCuratedCommunityModel()
    model.addItem(createTestCommunityItem("community-a", permissions = @[createTestPermission("p1")]))
    model.addItem(createTestCommunityItem("community-b", name = "", available = false))
    let spy = newQtModelSpy()
    spy.enable()
    defer: spy.disable()

    model.addItem(createTestCommunityItem("community-a", permissions = @[createTestPermission("p1")]))
    model.addItem(createTestCommunityItem("community-b", name = "", available = false))

    check(spy.countDataChanged == 0)
    check(spy.countInserts == 0)

  test "a community filling its unknown entry changes that row only":
    let model = newCuratedCommunityModel()
    model.addItem(createTestCommunityItem("community-a"))
    model.addItem(createTestCommunityItem("community-b", name = "", available = false))
    model.addItem(createTestCommunityItem("community-c"))
    let spy = newQtModelSpy()
    spy.enable()
    defer: spy.disable()

    model.addItem(createTestCommunityItem("community-b", name = "Fetched", available = true))

    let changes = spy.getDataChanged()
    check(changes.len == 1)
    check(changes[0].topLeft == 1)
    check(changes[0].bottomRight == 1)
    check(spy.countInserts == 0)
    check(model.getItemById("community-b").getName() == "Fetched")

  test "communities dropped from the directory are removed and the rest are kept":
    let model = newCuratedCommunityModel()
    model.addItem(createTestCommunityItem("community-a"))
    model.addItem(createTestCommunityItem("community-b"))
    model.addItem(createTestCommunityItem("community-c"))
    let spy = newQtModelSpy()
    spy.enable()
    defer: spy.disable()

    model.removeItemsNotIn(toHashSet(["community-a", "community-c"]))

    check(model.rowCount() == 2)
    check(not model.containsItemWithId("community-b"))
    check(model.containsItemWithId("community-a"))
    check(model.containsItemWithId("community-c"))
    check(spy.countRemoves == 1)
    check(spy.countDataChanged == 0)

  test "keeping every listed community removes no row":
    let model = newCuratedCommunityModel()
    model.addItem(createTestCommunityItem("community-a"))
    let spy = newQtModelSpy()
    spy.enable()
    defer: spy.disable()

    model.removeItemsNotIn(toHashSet(["community-a", "community-z"]))

    check(model.rowCount() == 1)
    check(spy.countRemoves == 0)
