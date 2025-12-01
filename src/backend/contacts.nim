import json
import core, ../app_service/common/utils
import response_type

export response_type

proc getContacts*(): RpcResponse[JsonNode] =
  let payload = %* []
  result = callPrivateRPC("contacts".prefix, payload)

proc blockContact*(id: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("blockContact".prefix, %* [id])

proc unblockContact*(id: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("unblockContact".prefix, %* [id])

proc removeContact*(id: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("removeContact".prefix, %* [id])

proc setContactLocalNickname*(id: string, name: string): RpcResponse[JsonNode] =
  let payload = %* [{
    "id": id,
    "nickname": name
  }]
  result = callPrivateRPC("setContactLocalNickname".prefix, payload)

proc sendContactRequest*(id: string, message: string): RpcResponse[JsonNode] =
  let payload = %* [{
      "id": id,
      "message": message
    }]
  result = callPrivateRPC("sendContactRequest".prefix, payload)

proc acceptLatestContactRequestForContact*(id: string): RpcResponse[JsonNode] =
  let payload = %* [{
      "id": id
    }]
  result = callPrivateRPC("acceptLatestContactRequestForContact".prefix, payload)

proc acceptContactRequest*(id, contactId: string): RpcResponse[JsonNode] =
  let payload = %* [{
      "id": id,
      "contactId": contactId
    }]
  result = callPrivateRPC("acceptContactRequest".prefix, payload)

proc dismissLatestContactRequestForContact*(id: string): RpcResponse[JsonNode] =
  let payload = %*[{
    "id": id
  }]
  result = callPrivateRPC("dismissLatestContactRequestForContact".prefix, payload)

proc declineContactRequest*(id, contactId: string): RpcResponse[JsonNode] =
  let payload = %*[{
    "id": id,
    "contactId": contactId
  }]
  result = callPrivateRPC("declineContactRequest".prefix, payload)

proc getLatestContactRequestForContact*(id: string): RpcResponse[JsonNode] =
  let payload = %* [id]
  result = callPrivateRPC("getLatestContactRequestForContact".prefix, payload)

proc sendContactUpdate*(publicKey, ensName, thumbnail: string): RpcResponse[JsonNode] =
  let payload = %* [publicKey, ensName, thumbnail]
  result = callPrivateRPC("sendContactUpdate".prefix, payload)

proc getImageServerURL*(): RpcResponse[JsonNode] =
  let payload = %* []
  result = callPrivateRPC("imageServerURL".prefix, payload)

proc markAsTrusted*(pubkey: string): RpcResponse[JsonNode] =
  let payload = %* [pubkey]
  result = callPrivateRPC("markAsTrusted".prefix, payload)

proc markUntrustworthy*(pubkey: string): RpcResponse[JsonNode] =
  let payload = %* [pubkey]
  result = callPrivateRPC("markAsUntrustworthy".prefix, payload)

proc removeTrustStatus*(pubkey: string): RpcResponse[JsonNode] =
  let payload = %* [pubkey]
  result = callPrivateRPC("removeTrustStatus".prefix, payload)

proc retractContactRequest*(pubkey: string): RpcResponse[JsonNode] =
  let payload = %*[{
    "id": pubkey
  }]
  result = callPrivateRPC("retractContactRequest".prefix, payload)

proc requestContactInfo*(pubkey: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("requestContactInfoFromMailserver".prefix, %*[pubkey])

proc getProfileShowcaseForContact*(contactId: string, validate: bool): RpcResponse[JsonNode] =
  let payload = %* [contactId, validate]
  result = callPrivateRPC("getProfileShowcaseForContact".prefix, payload)