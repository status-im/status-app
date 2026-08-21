import nimqml, json, sequtils

import io_interface

import models/profile_save_data
import models/showcase_preferences_generic_model
import models/showcase_preferences_social_links_model

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      showcasePreferencesCommunitiesModel: ShowcasePreferencesGenericModel
      showcasePreferencesAccountsModel: ShowcasePreferencesGenericModel
      showcasePreferencesCollectiblesModel: ShowcasePreferencesGenericModel
      showcasePreferencesAssetsModel: ShowcasePreferencesGenericModel
      showcasePreferencesSocialLinksModel: ShowcasePreferencesSocialLinkModel

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.showcasePreferencesCommunitiesModel = newShowcasePreferencesGenericModel()
    result.showcasePreferencesAccountsModel = newShowcasePreferencesGenericModel()
    result.showcasePreferencesCollectiblesModel = newShowcasePreferencesGenericModel()
    result.showcasePreferencesAssetsModel = newShowcasePreferencesGenericModel()
    result.showcasePreferencesSocialLinksModel = newShowcasePreferencesSocialLinkModel()

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc bioChanged*(self: View) {.signal.}
  proc getBio(self: View): string {.slot.} =
    self.delegate.getBio()
  QtProperty[string] bio:
    read = getBio
    notify = bioChanged

  proc emitBioChangedSignal*(self: View) =
    self.bioChanged()

  proc profileIdentitySaveSucceeded*(self: View) {.signal.}
  proc emitProfileIdentitySaveSucceededSignal*(self: View) =
    self.profileIdentitySaveSucceeded()

  proc profileIdentitySaveFailed*(self: View) {.signal.}
  proc emitProfileIdentitySaveFailedSignal*(self: View) =
    self.profileIdentitySaveFailed()

  proc profileShowcasePreferencesSaveSucceeded*(self: View) {.signal.}
  proc emitProfileShowcasePreferencesSaveSucceededSignal*(self: View) =
    self.profileShowcasePreferencesSaveSucceeded()

  proc profileShowcasePreferencesSaveFailed*(self: View) {.signal.}
  proc emitProfileShowcasePreferencesSaveFailedSignal*(self: View) =
    self.profileShowcasePreferencesSaveFailed()

  proc getShowcasePreferencesCommunitiesModel(self: View): QAbstractListModel {.slot.} =
    return self.showcasePreferencesCommunitiesModel
  QtProperty[QAbstractListModel] showcasePreferencesCommunitiesModel:
    read = getShowcasePreferencesCommunitiesModel

  proc getShowcasePreferencesAccountsModel(self: View): QAbstractListModel {.slot.} =
    return self.showcasePreferencesAccountsModel
  QtProperty[QAbstractListModel] showcasePreferencesAccountsModel:
    read = getShowcasePreferencesAccountsModel

  proc getShowcasePreferencesCollectiblesModel(self: View): QAbstractListModel {.slot.} =
    return self.showcasePreferencesCollectiblesModel
  QtProperty[QAbstractListModel] showcasePreferencesCollectiblesModel:
    read = getShowcasePreferencesCollectiblesModel

  proc getShowcasePreferencesAssetsModel(self: View): QAbstractListModel {.slot.} =
    return self.showcasePreferencesAssetsModel
  QtProperty[QAbstractListModel] showcasePreferencesAssetsModel:
    read = getShowcasePreferencesAssetsModel

  proc getShowcasePreferencesSocialLinksModel(self: View): QAbstractListModel {.slot.} =
    return self.showcasePreferencesSocialLinksModel
  QtProperty[QAbstractListModel] showcasePreferencesSocialLinksModel:
    read = getShowcasePreferencesSocialLinksModel

  proc saveProfileIdentityChanges(self: View, profileDataChanges: string) {.slot.} =
    let profileDataChangesObj = profileDataChanges.parseJson
    let identityChangesInfo = profileDataChangesObj.toIdentityChangesSaveData()
    self.delegate.saveProfileIdentityChanges(identityChangesInfo)

  proc saveProfileShowcasePreferences(self: View, profileData: string) {.slot.} =
    let profileDataObj = profileData.parseJson
    let showcase = profileDataObj.toShowcaseSaveData()
    self.delegate.saveProfileShowcasePreferences(showcase)

  proc getProfileShowcaseSocialLinksLimit*(self: View): int {.slot.} =
    self.delegate.getProfileShowcaseSocialLinksLimit()

  proc getProfileShowcaseEntriesLimit*(self: View): int {.slot.} =
    self.delegate.getProfileShowcaseEntriesLimit()

  proc requestProfileShowcasePreferences(self: View) {.slot.} =
    self.delegate.requestProfileShowcasePreferences()

  proc loadProfileShowcasePreferencesCommunities*(self: View, items: seq[ShowcasePreferencesGenericItem]) =
    self.showcasePreferencesCommunitiesModel.setItems(items)

  proc loadProfileShowcasePreferencesAccounts*(self: View, items: seq[ShowcasePreferencesGenericItem]) =
    self.showcasePreferencesAccountsModel.setItems(items)

  proc loadProfileShowcasePreferencesCollectibles*(self: View, items: seq[ShowcasePreferencesGenericItem]) =
    self.showcasePreferencesCollectiblesModel.setItems(items)

  proc loadProfileShowcasePreferencesAssets*(self: View, items: seq[ShowcasePreferencesGenericItem]) =
    self.showcasePreferencesAssetsModel.setItems(items)

  proc loadProfileShowcasePreferencesSocialLinks*(self: View, items: seq[ShowcasePreferencesSocialLinkItem]) =
    self.showcasePreferencesSocialLinksModel.setItems(items)

  proc delete*(self: View) =
    self.QObject.delete

