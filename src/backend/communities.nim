import json, strutils
import core, ../app_service/common/utils
import response_type

import interpret/cropped_image

export response_type

proc getCommunityTags*(): RpcResponse[JsonNode] =
  result = callPrivateRPC("communityTags".prefix)

proc muteCategory*(communityId: string, categoryId: string, interval: int): RpcResponse[JsonNode] =
  result = callPrivateRPC("muteCommunityCategory".prefix, %* [
    {
      "communityId": communityId,
      "categoryId": categoryId,
      "mutedType": interval,
    }
  ])

proc unmuteCategory*(communityId: string, categoryId: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("unmuteCommunityCategory".prefix, %* [communityId, categoryId])

proc getCuratedCommunities*(): RpcResponse[JsonNode] =
  let payload = %* []
  result = callPrivateRPC("curatedCommunities".prefix, payload)

proc getAllCommunities*(): RpcResponse[JsonNode] =
  result = callPrivateRPC("communities".prefix)

proc isDisplayNameDupeOfCommunityMember*(displayName: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("isDisplayNameDupeOfCommunityMember".prefix, %* [displayName])

proc spectateCommunity*(communityId: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("spectateCommunity".prefix, %*[communityId])

proc generateJoiningCommunityRequestsForSigning*(
    memberPubKey: string,
    communityId: string,
    addressesToReveal: seq[string]
  ): RpcResponse[JsonNode] =
  let payload = %*[memberPubKey, communityId, addressesToReveal]
  result = callPrivateRPC("generateJoiningCommunityRequestsForSigning".prefix, payload)

proc generateEditCommunityRequestsForSigning*(
    memberPubKey: string,
    communityId: string,
    addressesToReveal: seq[string]
  ): RpcResponse[JsonNode] =
  let payload = %*[memberPubKey, communityId, addressesToReveal]
  result = callPrivateRPC("generateEditCommunityRequestsForSigning".prefix, payload)

proc requestToJoinCommunity*(
    communityId: string,
    ensName: string,
    addressesToShare: seq[string],
    signatures: seq[string],
    airdropAddress: string,
  ): RpcResponse[JsonNode] =
  result = callPrivateRPC("requestToJoinCommunity".prefix, %*[{
    "communityId": communityId,
    "ensName": ensName,
    "addressesToReveal": addressesToShare,
    "signatures": signatures,
    "airdropAddress": airdropAddress,
  }])

proc editSharedAddresses*(
    communityId: string,
    addressesToShare: seq[string],
    signatures: seq[string],
    airdropAddress: string,
  ): RpcResponse[JsonNode] =
  result = callPrivateRPC("editSharedAddressesForCommunity".prefix, %*[{
    "communityId": communityId,
    "addressesToReveal": addressesToShare,
    "signatures": signatures,
    "airdropAddress": airdropAddress,
  }])

proc getRevealedAccountsForMember*(
    communityId: string,
    memberPubkey: string,
  ): RpcResponse[JsonNode] =
  result = callPrivateRPC("getRevealedAccounts".prefix, %*[communityId, memberPubkey])

proc getRevealedAccountsForAllMembers*(
    communityId: string,
  ): RpcResponse[JsonNode] =
  result = callPrivateRPC("getRevealedAccountsForAllMembers".prefix, %*[communityId])

proc checkPermissionsToJoinCommunity*(communityId: string, addresses: seq[string]): RpcResponse[JsonNode] =
  result = callPrivateRPC("checkPermissionsToJoinCommunity".prefix, %*[{
    "communityId": communityId,
    "addresses": addresses
  }])

proc reevaluateCommunityMembersPermissions*(
    communityId: string,
  ): RpcResponse[JsonNode] =
  result = callPrivateRPC("reevaluateCommunityMembersPermissions".prefix, %*[{
    "communityId": communityId
  }])

proc checkCommunityChannelPermissions*(communityId: string, chatId: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("checkCommunityChannelPermissions".prefix, %*[{
    "communityId": communityId,
    "chatId": chatId
  }])

proc checkAllCommunityChannelsPermissions*(communityId: string, addresses: seq[string]): RpcResponse[JsonNode] =
  result = callPrivateRPC("checkAllCommunityChannelsPermissions".prefix, %*[{
    "communityId": communityId,
    "addresses": addresses,
  }])

proc allNonApprovedCommunitiesRequestsToJoin*(): RpcResponse[JsonNode] =
  result = callPrivateRPC("allNonApprovedCommunitiesRequestsToJoin".prefix)

proc cancelRequestToJoinCommunity*(requestId: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("cancelRequestToJoinCommunity".prefix, %*[{
    "id": requestId
  }])

proc leaveCommunity*(communityId: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("leaveCommunity".prefix, %*[communityId])

proc createCommunity*(
    name: string,
    description: string,
    introMessage: string,
    outroMessage: string,
    access: int,
    color: string,
    tags: string,
    imageUrl: string,
    aX: int, aY: int, bX: int, bY: int,
    historyArchiveSupportEnabled: bool,
    pinMessageAllMembersEnabled: bool,
    bannerJsonStr: string
    ): RpcResponse[JsonNode] =
  let bannerImage = newCroppedImage(bannerJsonStr)
  result = callPrivateRPC("createCommunity".prefix, %*[{
      # TODO this will need to be renamed membership (small m)
      "Membership": access,
      "name": name,
      "description": description,
      "introMessage": introMessage,
      "outroMessage": outroMessage,
      "ensOnly": false, # TODO ensOnly is no longer supported. Remove this when we remove it in status-go
      "color": color,
      "tags": parseJson(tags),
      "image": imageUrl,
      "imageAx": aX,
      "imageAy": aY,
      "imageBx": bX,
      "imageBy": bY,
      "historyArchiveSupportEnabled": historyArchiveSupportEnabled,
      "pinMessageAllMembersEnabled": pinMessageAllMembersEnabled,
      "banner": bannerImage
    }])

proc editCommunity*(
    communityId: string,
    name: string,
    description: string,
    introMessage: string,
    outroMessage: string,
    access: int,
    color: string,
    tags: string,
    imageUrl: string,
    aX: int,
    aY: int,
    bX: int,
    bY: int,
    bannerJsonStr: string,
    historyArchiveSupportEnabled: bool,
    pinMessageAllMembersEnabled: bool
    ): RpcResponse[JsonNode] =
  let bannerImage = newCroppedImage(bannerJsonStr)
  result = callPrivateRPC("editCommunity".prefix, %*[{
    "CommunityID": communityId,
    "membership": access,
    "name": name,
    "description": description,
    "introMessage": introMessage,
    "outroMessage": outroMessage,
    "ensOnly": false, # TODO ensOnly is no longer supported. Remove this when we remove it in status-go
    "color": color,
    "tags": parseJson(tags),
    "image": imageUrl,
    "imageAx": aX,
    "imageAy": aY,
    "imageBx": bX,
    "imageBy": bY,
    "banner": bannerImage,
    "historyArchiveSupportEnabled": historyArchiveSupportEnabled,
    "pinMessageAllMembersEnabled": pinMessageAllMembersEnabled,
  }])

proc requestImportDiscordCommunity*(
    name: string,
    description: string,
    introMessage: string,
    outroMessage: string,
    access: int,
    color: string,
    tags: string,
    imageUrl: string,
    aX: int, aY: int, bX: int, bY: int,
    historyArchiveSupportEnabled: bool,
    pinMessageAllMembersEnabled: bool,
    filesToImport: seq[string],
    fromTimestamp: int,
    ): RpcResponse[JsonNode] =
  result = callPrivateRPC("requestImportDiscordCommunity".prefix, %*[{
      # TODO this will need to be renamed membership (small m)
      "Membership": access,
      "name": name,
      "description": description,
      "introMessage": introMessage,
      "outroMessage": outroMessage,
      "ensOnly": false, # TODO ensOnly is no longer supported. Remove this when we remove it in status-go
      "color": color,
      "tags": parseJson(tags),
      "image": imageUrl,
      "imageAx": aX,
      "imageAy": aY,
      "imageBx": bX,
      "imageBy": bY,
      "historyArchiveSupportEnabled": historyArchiveSupportEnabled,
      "pinMessageAllMembersEnabled": pinMessageAllMembersEnabled,
      "from": fromTimestamp,
      "filesToImport": filesToImport
    }])

proc requestImportDiscordChannel*(
    name: string,
    discordChannelId: string,
    communityId: string,
    description: string,
    color: string,
    emoji: string,
    filesToImport: seq[string],
    fromTimestamp: int,
  ): RpcResponse[JsonNode] =
  result = callPrivateRPC("requestImportDiscordChannel".prefix, %*[{
      "name": name,
      "discordChannelId": discordChannelId,
      "communityId": communityId,
      "description": description,
      "color": color,
      "emoji": emoji,
      "filesToImport": filesToImport,
      "from": fromTimestamp
    }])

proc createCommunityTokenPermission*(communityId: string, permissionType: int, tokenCriteria: string, chatIDs: seq[string], isPrivate: bool): RpcResponse[JsonNode] =
  result = callPrivateRPC("createCommunityTokenPermission".prefix, %*[{
    "communityId": communityId,
    "type": permissionType,
    "tokenCriteria": parseJson(tokenCriteria),
    "chat_ids": chatIDs,
    "isPrivate": isPrivate
  }])

proc editCommunityTokenPermission*(communityId: string, permissionId: string, permissionType: int, tokenCriteria: string, chatIDs: seq[string], isPrivate: bool): RpcResponse[JsonNode] =
  result = callPrivateRPC("editCommunityTokenPermission".prefix, %*[{
    "communityId": communityId,
    "permissionId": permissionId,
    "type": permissionType,
    "tokenCriteria": parseJson(tokenCriteria),
    "chat_ids": chatIDs,
    "isPrivate": isPrivate
  }])

proc deleteCommunityTokenPermission*(communityId: string, permissionId: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("deleteCommunityTokenPermission".prefix, %*[{
    "communityId": communityId,
    "permissionId": permissionId
  }])

proc requestCancelDiscordCommunityImport*(communityId: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("requestCancelDiscordCommunityImport".prefix, %*[communityId])

proc requestCancelDiscordChannelImport*(discordChannelId: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("requestCancelDiscordChannelImport".prefix, %*[discordChannelId])


proc createCommunityChannel*(
    communityId: string,
    name: string,
    description: string,
    emoji: string,
    color: string,
    categoryId: string,
    viewersCanPostReactions: bool,
    hideIfPermissionsNotMet: bool
    ): RpcResponse[JsonNode] =
  result = callPrivateRPC("createCommunityChat".prefix, %*[
    communityId,
    {
      "permissions": {
        "access": 1 # TODO get this from user selected privacy setting
      },
      "identity": {
        "display_name": name,
        "description": description,
        "emoji": emoji,
        "color": color
      },
      "category_id": categoryId,
      "viewers_can_post_reactions": viewersCanPostReactions,
      "hide_if_permissions_not_met": hideIfPermissionsNotMet
    }])

proc editCommunityChannel*(
    communityId: string,
    channelId: string,
    name: string,
    description: string,
    emoji: string,
    color: string,
    categoryId: string,
    position: int,
    viewersCanPostReactions: bool,
    hideIfPermissionsNotMet: bool
    ): RpcResponse[JsonNode] =
  result = callPrivateRPC("editCommunityChat".prefix, %*[
    communityId,
    channelId.replace(communityId, ""),
    {
      "permissions": {
        "access": 1 # TODO get this from user selected privacy setting
      },
      "identity": {
        "display_name": name,
        "description": description,
        "emoji": emoji,
        "color": color
      },
      "category_id": categoryId,
      "position": position,
      "viewers_can_post_reactions": viewersCanPostReactions,
      "hide_if_permissions_not_met": hideIfPermissionsNotMet
    }])

proc reorderCommunityCategories*(communityId: string, categoryId: string, position: int): RpcResponse[JsonNode] =
  result = callPrivateRPC("reorderCommunityCategories".prefix, %*[
    {
      "communityId": communityId,
      "categoryId": categoryId,
      "position": position
    }])

proc reorderCommunityChat*(
    communityId: string,
    categoryId: string,
    chatId: string,
    position: int
    ): RpcResponse[JsonNode] =
  result = callPrivateRPC("reorderCommunityChat".prefix, %*[
    {
      "communityId": communityId,
      "categoryId": categoryId,
      "chatId": chatId,
      "position": position
    }])

proc deleteCommunityChat*(
    communityId: string,
    chatId: string
    ): RpcResponse[JsonNode]  =
  result = callPrivateRPC("deleteCommunityChat".prefix, %*[communityId, chatId])

proc createCommunityCategory*(
    communityId: string,
    name: string,
    channels: seq[string]
    ): RpcResponse[JsonNode] =
  result = callPrivateRPC("createCommunityCategory".prefix, %*[
    {
      "communityId": communityId,
      "categoryName": name,
      "chatIds": channels
    }])

proc editCommunityCategory*(
    communityId: string,
    categoryId: string,
    name: string,
    channels: seq[string]
    ): RpcResponse[JsonNode] =
  result = callPrivateRPC("editCommunityCategory".prefix, %*[
    {
      "communityId": communityId,
      "categoryId": categoryId,
      "categoryName": name,
      "chatIds": channels
    }])

proc toggleCollapsedCommunityCategory*(communityId: string, categoryId: string, collapsed: bool): RpcResponse[JsonNode] =
  result = callPrivateRPC("toggleCollapsedCommunityCategory".prefix, %*[
    {
      "communityId": communityId,
      "categoryId": categoryId,
      "collapsed": collapsed
    }])

proc collapsedCommunityCategories*(): RpcResponse[JsonNode] =
  result = callPrivateRPC("collapsedCommunityCategories".prefix, %*[])

proc deleteCommunityCategory*(
    communityId: string,
    categoryId: string
    ): RpcResponse[JsonNode] =
  result = callPrivateRPC("deleteCommunityCategory".prefix, %*[
    {
      "communityId": communityId,
      "categoryId": categoryId
    }])

proc collectCommunityMetrics*(communityId: string, metricsType: int, intervals: JsonNode
    ):RpcResponse[JsonNode] =
  result = callPrivateRPC("collectCommunityMetrics".prefix, %*[
    {
      "communityId": communityId,
      "type": metricsType,
      "intervals": intervals
    }])

proc requestCommunityInfo*(communityId: string, tryDatabase: bool): RpcResponse[JsonNode] =
  result = callPrivateRPC("fetchCommunity".prefix, %*[{
    "communityKey": communityId,
    "tryDatabase": tryDatabase,
    "waitForResponse": true
  }])

proc exportCommunity*(communityId: string): RpcResponse[JsonNode]  =
  result = callPrivateRPC("exportCommunity".prefix, %*[communityId])

proc speedupArchivesImport*(): RpcResponse[JsonNode] =
  result = callPrivateRPC("speedupArchivesImport".prefix)

proc slowdownArchivesImport*(): RpcResponse[JsonNode] =
  result = callPrivateRPC("slowdownArchivesImport".prefix)

proc removeUserFromCommunity*(communityId: string, pubKey: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("removeUserFromCommunity".prefix, %*[communityId, pubKey])

proc acceptRequestToJoinCommunity*(requestId: string): RpcResponse[JsonNode]  =
  return callPrivateRPC("acceptRequestToJoinCommunity".prefix, %*[{
    "id": requestId
  }])

proc declineRequestToJoinCommunity*(requestId: string): RpcResponse[JsonNode]  =
  return callPrivateRPC("declineRequestToJoinCommunity".prefix, %*[{
    "id": requestId
  }])

proc banUserFromCommunity*(communityId: string, pubKey: string, deleteAllMessages: bool): RpcResponse[JsonNode]  =
  return callPrivateRPC("banUserFromCommunity".prefix, %*[{
    "communityId": communityId,
    "user": pubKey,
    "deleteAllMessages": deleteAllMessages,
  }])

proc unbanUserFromCommunity*(communityId: string, pubKey: string): RpcResponse[JsonNode]  =
  return callPrivateRPC("unbanUserFromCommunity".prefix, %*[{
    "communityId": communityId,
    "user": pubKey
  }])

proc setCommunityMuted*(communityId: string, mutedType: int): RpcResponse[JsonNode]  =
  return callPrivateRPC("setCommunityMuted".prefix, %*[{
    "communityId": communityId,
    "mutedType": mutedType
  }])

proc shareCommunityToUsers*(communityId: string, pubKeys: seq[string], inviteMessage: string): RpcResponse[JsonNode] =
  return callPrivateRPC("shareCommunity".prefix, %*[{
    "communityId": communityId,
    "users": pubKeys,
    "inviteMessage": inviteMessage
  }])

proc getCommunitiesSettings*(): RpcResponse[JsonNode] =
  return callPrivateRPC("getCommunitiesSettings".prefix, %*[])

proc requestExtractDiscordChannelsAndCategories*(filesToImport: seq[string]): RpcResponse[JsonNode] =
  return callPrivateRPC("requestExtractDiscordChannelsAndCategories".prefix, %*[filesToImport])

proc getCheckChannelPermissionResponses*(communityId: string,): RpcResponse[JsonNode] =
  return callPrivateRPC("getCheckChannelPermissionResponses".prefix, %*[communityId])

proc getCommunityPublicKeyFromPrivateKey*(communityPrivateKey: string,): RpcResponse[JsonNode] =
  return callPrivateRPC("getCommunityPublicKeyFromPrivateKey".prefix, %*[communityPrivateKey])

proc getCommunityMembersForWalletAddresses*(communityId: string, chainId: int): RpcResponse[JsonNode] =
  return callPrivateRPC("getCommunityMembersForWalletAddresses".prefix, %* [communityId, chainId])

proc promoteSelfToControlNode*(communityId: string): RpcResponse[JsonNode] =
  let payload = %*[communityId]
  return core.callPrivateRPC("wakuext_promoteSelfToControlNode", payload)

proc markAllReadInCommunity*(communityId: string,): RpcResponse[JsonNode] =
  return callPrivateRPC("markAllReadInCommunity".prefix, %*[communityId])