  proc isKeycardAccount*(self: Service, account: WalletAccountDto): bool =
    if account.isNil or
      account.keyUid.len == 0 or
      account.path.len == 0 or
      utils.isPathOutOfTheDefaultStatusDerivationTree(account.path):
        return false
    let kp = self.getKeypairByKeyUid(account.keyUid)
    if kp.isNil:
      return false
    return kp.coldWalletType == ColdWalletTypeStatusKeycard
