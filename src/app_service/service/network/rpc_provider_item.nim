import nimqml, std/strformat

import backend/network_types

export RpcProviderType, RpcProviderAuthType

QtObject:
  type RpcProviderItem* = ref object of QObject
    id*: int
    chainId*: int
    name*: string
    url*: string
    isRpsLimiterEnabled*: bool
    providerType*: RpcProviderType
    isEnabled*: bool
    authType*: RpcProviderAuthType
    authLogin*: string
    authPassword*: string
    authToken*: string

  proc setup*(self: RpcProviderItem,
      id: int,
      chainId: int,
      name: string,
      url: string,
      isRpsLimiterEnabled: bool,
      providerType: RpcProviderType,
      isEnabled: bool,
      authType: RpcProviderAuthType,
      authLogin: string,
      authPassword: string,
      authToken: string
      )
  proc delete*(self: RpcProviderItem)
  proc rpcProviderDtoToItem*(rpcProvider: RpcProviderDto): RpcProviderItem =
    new(result, delete)
    result.setup(rpcProvider.id, rpcProvider.chainId, rpcProvider.name, rpcProvider.url, rpcProvider.isRpsLimiterEnabled,
      rpcProvider.providerType, rpcProvider.isEnabled, rpcProvider.authType, rpcProvider.authLogin, rpcProvider.authPassword,
      rpcProvider.authToken)
    
  proc rpcProviderItemToDto*(rpcProvider: RpcProviderItem): RpcProviderDto =
    result = RpcProviderDto()
    result.id = rpcProvider.id
    result.chainId = rpcProvider.chainId
    result.name = rpcProvider.name
    result.url = rpcProvider.url
    result.isRpsLimiterEnabled = rpcProvider.isRpsLimiterEnabled
    result.providerType = rpcProvider.providerType
    result.isEnabled = rpcProvider.isEnabled
    result.authType = rpcProvider.authType
    result.authLogin = rpcProvider.authLogin
    result.authPassword = rpcProvider.authPassword
    result.authToken = rpcProvider.authToken

  proc `$`*(self: RpcProviderItem): string =
    result = fmt"""RpcProviderItem(
      id: {self.id},
      chainId: {self.chainId},
      name: {self.name},
      url: {self.url},
      isRpsLimiterEnabled: {self.isRpsLimiterEnabled},
      providerType: {self.providerType},
      isEnabled: {self.isEnabled},
      authType: {self.authType},
      authLogin: {self.authLogin},
      authPassword: {self.authPassword},
      authToken: {self.authToken}
    )"""

  proc id*(self: RpcProviderItem): int {.slot.} =
    return self.id
  QtProperty[int] id:
    read = id

  proc chainId*(self: RpcProviderItem): int {.slot.} =
    return self.chainId
  QtProperty[int] chainId:
    read = chainId
  
  proc name*(self: RpcProviderItem): string {.slot.} =
    return self.name
  QtProperty[string] name:
    read = name

  proc url*(self: RpcProviderItem): string {.slot.} =
    return self.url
  QtProperty[string] url:
    read = url

  proc isRpsLimiterEnabled*(self: RpcProviderItem): bool {.slot.} =
    return self.isRpsLimiterEnabled
  QtProperty[bool] isRpsLimiterEnabled:
    read = isRpsLimiterEnabled

  proc getProviderType*(self: RpcProviderItem): string {.slot.} =
    return $self.providerType
  QtProperty[string] providerType:
    read = getProviderType

  proc isEnabled*(self: RpcProviderItem): bool {.slot.} =
    return self.isEnabled
  QtProperty[bool] isEnabled:
    read = isEnabled

  proc getAuthType*(self: RpcProviderItem): string {.slot.} =
    return $self.authType
  QtProperty[string] authType:
    read = getAuthType

  proc authLogin*(self: RpcProviderItem): string {.slot.} =
    return self.authLogin
  QtProperty[string] authLogin:
    read = authLogin
  
  proc authPassword*(self: RpcProviderItem): string {.slot.} =
    return self.authPassword
  QtProperty[string] authPassword:
    read = authPassword
  
  proc authToken*(self: RpcProviderItem): string {.slot.} =
    return self.authToken
  QtProperty[string] authToken:
    read = authToken

  proc delete*(self: RpcProviderItem) =
      self.QObject.delete

  proc setup*(self: RpcProviderItem,
      id: int,
      chainId: int,
      name: string,
      url: string,
      isRpsLimiterEnabled: bool,
      providerType: RpcProviderType,
      isEnabled: bool,
      authType: RpcProviderAuthType,
      authLogin: string,
      authPassword: string,
      authToken: string
      ) =
        self.QObject.setup
        self.id = id
        self.chainId = chainId
        self.name = name
        self.url = url
        self.isRpsLimiterEnabled = isRpsLimiterEnabled
        self.providerType = providerType
        self.isEnabled = isEnabled
        self.authType = authType
        self.authLogin = authLogin
        self.authPassword = authPassword
        self.authToken = authToken