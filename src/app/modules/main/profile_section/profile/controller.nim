import io_interface

import app/global/app_signals
import app/core/eventemitter
import app_service/service/profile/service as profile_service
import app_service/service/settings/service as settings_service
import app_service/service/community/service as community_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/token/service as token_service

import app_service/service/profile/dto/profile_showcase_preferences

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    profileService: profile_service.Service
    settingsService: settings_service.Service
    communityService: community_service.Service
    walletAccountService: wallet_account_service.Service
    tokenService: token_service.Service

proc newController*(
    delegate: io_interface.AccessInterface,
    events: EventEmitter,
    profileService: profile_service.Service,
    settingsService: settings_service.Service,
    communityService: community_service.Service,
    walletAccountService: wallet_account_service.Service,
    tokenService: token_service.Service): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.profileService = profileService
  result.settingsService = settingsService
  result.communityService = communityService
  result.walletAccountService = walletAccountService
  result.tokenService = tokenService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.on(SIGNAL_BIO_UPDATED) do(e: Args):
    let args = SettingsTextValueArgs(e)
    self.delegate.onBioChanged(args.value)

  self.events.on(SIGNAL_PROFILE_SHOWCASE_PREFERENCES_SAVE_SUCCEEDED) do(e: Args):
    self.delegate.onProfileShowcasePreferencesSaveSucceeded()

  self.events.on(SIGNAL_PROFILE_SHOWCASE_PREFERENCES_SAVE_FAILED) do(e: Args):
    self.delegate.onProfileShowcasePreferencesSaveFailed()

  self.events.on(SIGNAL_PROFILE_SHOWCASE_PREFERENCES_LOADED) do(e: Args):
    let args = ProfileShowcasePreferencesArgs(e)
    self.delegate.loadProfileShowcasePreferences(args.preferences)

proc storeIdentityImage*(self: Controller, address: string, image: string, aX: int, aY: int, bX: int, bY: int): bool =
  let images = self.profileService.storeIdentityImage(address, image, aX, aY, bX, bY)
  return images.large.len > 0 or images.thumbnail.len > 0

proc deleteIdentityImage*(self: Controller, address: string): bool =
  self.profileService.deleteIdentityImage(address)

proc setDisplayName*(self: Controller, displayName: string): bool =
  self.profileService.setDisplayName(displayName)

proc getCommunityById*(self: Controller, id: string): lent CommunityDto =
  self.communityService.getCommunityById(id)

proc getAccountByAddress*(self: Controller, address: string): WalletAccountDto =
  self.walletAccountService.getAccountByAddress(address)

proc getWalletAccounts*(self: Controller): seq[wallet_account_service.WalletAccountDto] =
  self.walletAccountService.getWalletAccounts(true)

proc getBio*(self: Controller): string =
  self.settingsService.getBio()

proc setBio*(self: Controller, bio: string): bool =
  self.profileService.setBio(bio)

proc saveProfileShowcasePreferences*(self: Controller, preferences: ProfileShowcasePreferencesDto, revealedAddresses: seq[string]) =
  self.profileService.saveProfileShowcasePreferences(preferences)
  self.events.emit(MARK_WALLET_ADDRESSES_AS_SHOWN, WalletAddressesArgs(addresses: revealedAddresses))

proc requestProfileShowcasePreferences*(self: Controller) =
  self.profileService.requestProfileShowcasePreferences()

proc getProfileShowcaseSocialLinksLimit*(self: Controller): int =
  self.profileService.getProfileShowcaseSocialLinksLimit()

proc getProfileShowcaseEntriesLimit*(self: Controller): int =
  self.profileService.getProfileShowcaseEntriesLimit()

proc requestCommunityInfo*(self: Controller, communityId: string) =
  self.communityService.requestCommunityInfo(communityId)
