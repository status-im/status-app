const GENERATED* = "generated"
const SEED* = "seed"
const KEY* = "key"
const WATCH* = "watch"

const ZERO_ADDRESS* = "0x0000000000000000000000000000000000000000"

# Path of the Wallet XPUB, the extended public key from which any child wallet account can be derived
const PATH_WALLET_XPUB* = "m/44'/60'/0'"
# Wallet Root Path, under which all default (supported in keycard's metadata) wallet accounts are derived
const PATH_WALLET_ROOT* = "m/44'/60'/0'/0"
# EIP1581 Root Key, the extended key from which any whisper key/encryption key can be derived
const PATH_EIP_1581* = "m/43'/60'/1581'"
# BIP44-0 Wallet key, the default wallet key
const PATH_DEFAULT_WALLET* = PATH_WALLET_ROOT & "/0"
# EIP1581 Chat Key 0, the default whisper key
const PATH_WHISPER* = PATH_EIP_1581 & "/0'/0"
# EIP1581 Encryption Key
const PATH_ENCRYPTION* = PATH_EIP_1581 & "/1'/0"
