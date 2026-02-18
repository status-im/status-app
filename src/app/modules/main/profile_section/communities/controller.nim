import io_interface

import ../../../../../app_service/service/community/service as community_service


type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    communityService: community_service.Service

proc newController*(delegate: io_interface.AccessInterface,
  communityService: community_service.Service): Controller =
  result = Controller()
  result.delegate = delegate
  result.communityService = communityService

proc delete*(self: Controller) =
  discard

proc leaveCommunity*(self: Controller, communityID: string) =
  self.communityService.leaveCommunity(communityID)

proc setCommunityMuted*(self: Controller, communityID: string, mutedType: int) =
  self.communityService.setCommunityMuted(communityID, mutedType)

