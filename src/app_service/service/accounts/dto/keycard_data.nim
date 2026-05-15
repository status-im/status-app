import json

type
  KeycardData* = ref object
    keyUID*: string
    address*: string
    whisperPrivateKey*: string
    whisperPublicKey*: string
    whisperAddress*: string
    walletPublicKey*: string
    walletAddress*: string
    walletRootAddress*: string
    eip1581Address*: string
    encryptionPublicKey*: string
    walletXPub*: string
    coldWallet*: string

proc toJson*(self: KeycardData): JsonNode =
  result = %*{
    "keyUID": self.keyUID,
    "address": self.address,
    "whisperPrivateKey": self.whisperPrivateKey,
    "whisperPublicKey": self.whisperPublicKey,
    "whisperAddress": self.whisperAddress,
    "walletPublicKey": self.walletPublicKey,
    "walletAddress": self.walletAddress,
    "walletRootAddress": self.walletRootAddress,
    "eip1581Address": self.eip1581Address,
    "encryptionPublicKey": self.encryptionPublicKey,
    "walletXPub": self.walletXPub,
    "coldWallet": self.coldWallet
  }
