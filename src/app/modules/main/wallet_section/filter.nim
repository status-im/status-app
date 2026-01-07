import std/strformat

import ./controller

type Filter* = ref object
  controller: controller.Controller
  addresses*: seq[string]
  chainIds*: seq[int]
  allChainsEnabled*: bool
  isDirty*: bool

proc initFilter*(
  controller: controller.Controller
): Filter =
  result = Filter()
  result.controller = controller
  result.addresses = @[]
  result.chainIds = @[]
  result.allChainsEnabled = true
  result.isDirty = true

proc `$`*(self: Filter): string =
  result = fmt"""WalletFilter(
    addresses: {self.addresses},
    chainIds: {self.chainIds},
    )"""

proc setAddresses*(self: Filter, addresses: seq[string]) =
  self.addresses = addresses
  self.isDirty = true

proc setAddress*(self: Filter, address: string) =
  self.setAddresses(@[address])
  self.isDirty = true

proc removeAddress*(self: Filter, address: string) =
  if len(self.addresses) == 1 and self.addresses[0] == address:
    let accounts = self.controller.getWalletAccounts()
    self.setAddresses(@[accounts[0].address])
    self.isDirty = true
    return

  let ind = self.addresses.find(address)
  if ind > -1:
    self.addresses.delete(ind)

proc updateNetworks*(self: Filter) =
  self.chainIds = self.controller.getEnabledChainIds()
  self.allChainsEnabled = (self.chainIds.len == self.controller.getCurrentNetworks().len)
  self.isDirty = true

proc load*(self: Filter) =
  self.updateNetworks()
