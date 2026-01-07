import std/strformat

import app/modules/shared_models/contract_model as contract_model
import app/modules/shared_models/contract_item as contract_item
  
type Item* = object
  id: string
  name: string
  description: string
  fees: string
  logoUrl: string  
  hostname: string
  supportsSinglePurchase: bool
  supportsRecurrentPurchase: bool
  supportedAssets: contract_model.Model
  urlsNeedParameters: bool

proc initItem*(
  id: string, 
  name: string, 
  description: string, 
  fees: string, 
  logoUrl: string, 
  hostname: string, 
  supportsSinglePurchase: bool, 
  supportsRecurrentPurchase: bool, 
  supportedAssets: seq[contract_item.Item], 
  urlsNeedParameters: bool): Item =
  result.id = id
  result.name = name
  result.description = description
  result.fees = fees
  result.logoUrl = logoUrl
  result.hostname = hostname
  result.supportsSinglePurchase = supportsSinglePurchase
  result.supportsRecurrentPurchase = supportsRecurrentPurchase
  result.supportedAssets = contract_model.newModel()
  result.supportedAssets.setItems(supportedAssets)
  result.urlsNeedParameters = urlsNeedParameters

proc `$`*(self: Item): string =
  result = "Item("
  result &= fmt"id:{self.id}, "
  result &= fmt"name:{self.name}, "
  result &= fmt"description:{self.description}, "
  result &= fmt"fees:{self.fees}, "
  result &= fmt"logoUrl:{self.logoUrl}, "
  result &= fmt"hostname:{self.hostname}, "
  result &= fmt"supportsSinglePurchase:{self.supportsSinglePurchase}, "
  result &= fmt"supportsRecurrentPurchase:{self.supportsRecurrentPurchase}, "
  result &= fmt"supportedAssets:{self.supportedAssets}, "
  result &= fmt"urlsNeedParameters:{self.urlsNeedParameters}, "
  result &= ")"

method getId*(self: Item): string {.base.} =
  return self.id

method getName*(self: Item): string {.base.} =
  return self.name

method getDescription*(self: Item): string {.base.} =
  return self.description

method getFees*(self: Item): string {.base.} =
  return self.fees

method getLogoUrl*(self: Item): string {.base.} =
  return self.logoUrl

method getHostname*(self: Item): string {.base.} =
  return self.hostname

method getSupportsSinglePurchase*(self: Item): bool {.base.} =
  return self.supportsSinglePurchase

method getSupportsRecurrentPurchase*(self: Item): bool {.base.} =
  return self.supportsRecurrentPurchase

method getSupportedAssets*(self: Item): contract_model.Model {.base.} =
  return self.supportedAssets

method getUrlsNeedParameters*(self: Item): bool {.base.} =
  return self.urlsNeedParameters