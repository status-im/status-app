import json
import core, ../app_service/common/utils
import response_type

export response_type

proc setInstallationMetadata*(installationId: string, deviceName: string, deviceType: string):
  RpcResponse[JsonNode] =
  let payload = %* [installationId, {
    "name": deviceName,
    "deviceType": deviceType
  }]
  result = callPrivateRPC("setInstallationMetadata".prefix, payload)

proc setInstallationName*(installationId: string, name: string):
  RpcResponse[JsonNode] =
  let payload = %* [installationId, name]
  result = callPrivateRPC("setInstallationName".prefix, payload)

proc getOurInstallations*(): RpcResponse[JsonNode] =
  let payload = %* []
  result = callPrivateRPC("getOurInstallations".prefix, payload)

proc syncDevices*(preferredName: string, photoPath: string): RpcResponse[JsonNode] =
  let payload = %* [preferredName, photoPath]
  result = callPrivateRPC("syncDevices".prefix, payload)

proc sendPairInstallation*(): RpcResponse[JsonNode] =
  result = callPrivateRPC("sendPairInstallation".prefix)

proc finishPairingThroughSeedPhraseProcess*(installationId: string): RpcResponse[JsonNode] =
  let payload = %* [{
    "installationId": installationId,
  }]
  result = callPrivateRPC("enableInstallationAndPair".prefix, payload)

proc enableInstallationAndSync*(installationId: string): RpcResponse[JsonNode] =
  let payload = %* [{
    "installationId": installationId,
  }]
  result = callPrivateRPC("enableInstallationAndSync".prefix, payload)

proc unpairDevice*(installationId: string): RpcResponse[JsonNode] =
  let payload = %* [installationId]
  result = callPrivateRPC("disableInstallation".prefix, payload)

proc pairDevice*(installationId: string): RpcResponse[JsonNode] =
  let payload = %* [installationId]
  result = callPrivateRPC("enableInstallation".prefix, payload)

proc deleteDevice*(installationId: string): RpcResponse[JsonNode] =
  let payload = %* [installationId]
  result = callPrivateRPC("deleteInstallation".prefix, payload)
