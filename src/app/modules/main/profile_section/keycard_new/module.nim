import nimqml, json, os, strutils

import ./io_interface, ./view, ./controller
import ../io_interface as delegate_interface
import constants as main_constants
import app_service/service/wallet_account/service as wallet_account_service
import app/modules/shared/keypairs

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool

proc newModule*(
    delegate: delegate_interface.AccessInterface,
    walletAccountService: wallet_account_service.Service
    ): Module =
  result = Module()
  result.delegate = delegate
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, walletAccountService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method load*(self: Module) =
  self.view.load()
  self.controller.init()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.keycardNewModuleDidLoad()

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

method isKnownKeyUid*(self: Module, keyUid: string): bool =
  let keypair = self.controller.getKeypairByKeyUid(keyUid)
  if keypair.isNil or keypair.removed:
    return false
  return true

method getKeyPairItemForKeyUid*(self: Module, keyUid: string): KeyPairItem =
  let keypair = self.controller.getKeypairByKeyUid(keyUid)
  if keypair.isNil or keypair.removed:
    return nil
  let areTestNetworksEnabled = self.controller.areTestNetworksEnabled()
  return buildKeypairItem(keypair, areTestNetworksEnabled)

proc pairingJsonEntryIsValid(pairing: JsonNode): bool =
  if pairing.isNil or pairing.kind != JObject:
    return false
  let keyHex = pairing{"key"}.getStr("")
  let index = pairing{"index"}.getInt(-1)
  return keyHex.len > 0 and index >= 0

proc findPairingJsonForInstance(pairingsRoot: JsonNode, keycardUid: string): JsonNode =
  if pairingsRoot.isNil or pairingsRoot.kind != JObject or keycardUid.len == 0:
    return nil
  if pairingsRoot.hasKey(keycardUid):
    return pairingsRoot[keycardUid]
  for k, v in pairingsRoot.pairs:
    if cmpIgnoreCase(k, keycardUid) == 0:
      return v
  return nil

method keycardPairingExists*(self: Module, keycardUid: string): bool =
  if keycardUid.len == 0:
    return false
  let path = main_constants.KEYCARDPAIRINGDATAFILE
  if not fileExists(path):
    return false
  var data: string
  try:
    data = readFile(path)
  except CatchableError:
    return false
  if data.len == 0:
    return false
  var doc: JsonNode
  try:
    doc = parseJson(data)
  except CatchableError:
    return false
  if doc.kind != JObject:
    return false
  let entry = findPairingJsonForInstance(doc, keycardUid)
  return pairingJsonEntryIsValid(entry)