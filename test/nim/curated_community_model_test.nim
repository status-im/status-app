import unittest

import app/modules/main/communities/models/[curated_community_model, curated_community_item]

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
    tokenPermissionsItems = @[],
    amIBanned = amIBanned,
    joined = joined,
    encrypted = encrypted,
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
    check(updated.getPermissionsModel() != originalPermissionsModel)
    check(updated.getPermissionsModel() == replacement.getPermissionsModel())