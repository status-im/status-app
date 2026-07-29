import chronicles

import io_interface
import app_service/service/general/service as general_service

logScope:
  topics = "profile-section-logos-network-module-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    generalService: general_service.Service

proc newController*(
    delegate: io_interface.AccessInterface,
    generalService: general_service.Service,
  ): Controller =
  result = Controller()
  result.delegate = delegate
  result.generalService = generalService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  discard

proc getPeerCount*(self: Controller): int =
  return self.generalService.getWakuPeerCount()
