import std/strformat
import ./permissions
import ./accounts
import ../../../../../app_service/service/wallet_account/service as wallet_account_service

type
  Item* = object
    name*: string
    accounts*: AccountsModel
    permissions*: PermissionsModel
    
proc initItem*(
  name: string,
  permissions: seq[string]
): Item =
  result.name = name
  result.accounts = newAccountsModel()
  result.permissions = newPermissionsModel()
  for p in permissions:
    result.permissions.addItem(p)

proc `$`*(self: Item): string =
  result = fmt"""Dapps(
    name: {self.name}
    ]"""

proc addAccount*(self: Item, account: WalletAccountDto): void =
  self.accounts.addItem(account)
