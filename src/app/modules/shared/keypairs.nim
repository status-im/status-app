import chronicles

import ../shared_models/[keypair_item, currency_amount]
import ../../global/global_singleton

import ../../../app_service/service/wallet_account/dto/[keypair_dto]

export keypair_item

logScope:
  topics = "shared-keypairs"

proc buildKeypairItem*(keypair: KeypairDto, areTestNetworksEnabled: bool): KeyPairItem =
  if keypair.accounts.len == 0:
    ## we should never be here
    error "there must not be any keypair without accounts", keyUid=keypair.keyUid
    return
  let publicKey = keypair.accounts[0].publicKey # in case of other but the profile keypair we take public key of first account as keypair's public key
  var item = newKeyPairItem(keyUid = keypair.keyUid,
    pubKey = publicKey,
    locked = false,
    name = keypair.name,
    image = "",
    icon = "",
    pairType = KeyPairType.Unknown,
    derivedFrom = keypair.derivedFrom,
    lastUsedDerivationIndex = keypair.lastUsedDerivationIndex,
    migratedToColdWallet = keypair.migratedToColdWallet(),
    syncedFrom = keypair.syncedFrom)

  if keypair.keypairType == KeypairTypeProfile:
    item.setPubKey(singletonInstance.userProfile.getPubKey())
    item.setName(singletonInstance.userProfile.getName())
    item.setImage(singletonInstance.userProfile.getIcon())
    item.setPairType(KeyPairType.Profile.int)
  elif keypair.keypairType == KeypairTypeSeed:
    item.setIcon("key_pair_seed_phrase")
    item.setPairType(KeyPairType.SeedImport.int)
  elif keypair.keypairType == KeypairTypeKey:
    item.setIcon("objects")
    item.setPairType(KeyPairType.PrivateKeyImport.int)

  for acc in keypair.accounts:
    if acc.isChat:
      continue
    var icon = ""
    if acc.emoji.len == 0:
      icon = "wallet"
    item.addAccount(newKeyPairAccountItem(acc.name, acc.path, acc.address, acc.publicKey, acc.emoji, acc.colorId,
      icon, newCurrencyAmount(), balanceFetched = true, operability = acc.operable, acc.isWallet, areTestNetworksEnabled,
      acc.hideFromTotalBalance))
  return item

proc buildKeyPairsList*(keypairs: seq[KeypairDto], excludeAlreadyMigratedPairs: bool,
  excludePrivateKeyKeypairs: bool, areTestNetworksEnabled: bool = false): seq[KeyPairItem] =
  var items: seq[KeyPairItem]
  for kp in keypairs:
    let item = buildKeypairItem(kp, areTestNetworksEnabled)
    if item.isNil:
      continue
    if excludeAlreadyMigratedPairs and item.getMigratedToColdWallet():
      continue
    if item.getPairType() == KeypairType.Profile.int:
      items.insert(item, 0) # Status Account must be at first place
      continue
    if item.getPairType() == KeypairType.PrivateKeyImport.int and excludePrivateKeyKeypairs:
      continue
    items.add(item)
  if items.len == 0:
    debug "sm_there is no any key pair for the logged in user that is not already migrated to a keycard"
  return items
