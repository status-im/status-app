import QtQuick
import QtTest

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Controls

import QtQuick.Controls

import utils
import shared.stores
import AppLayouts.Wallet.popups.swap
import AppLayouts.Wallet.stores
import AppLayouts.Wallet
import AppLayouts.Wallet.adaptors

import Storybook
import Models
import Mocks

Item {
    id: root
    width: 800
    height: 700

    readonly property string ethGroupKey: Constants.ethGroupKey
    readonly property string sttGroupKey: Constants.sttGroupKey

    readonly property var dummySwapTransactionRoutes: SwapTransactionRoutes {}

    readonly property var swapStore: SwapStore {
        signal suggestedRoutesReady(var txRoutes, string errCode, string errDescription)
        signal transactionSent(var chainId,var txHash, var uuid, var error)
        signal transactionSendingComplete(var txHash,  var status)

        accounts: WalletAccountsModel {}
        function getWei2Eth(wei, decimals) {
            return wei/(10**decimals)
        }
        function fetchSuggestedRoutes(uuid, accountFrom, accountTo, amount, tokenFrom, tokenTo,
                                      fromChainID, toChainID, preferredChainIDs, sendType) {
                    swapStore.fetchSuggestedRoutesCalled()
        }
        function authenticateAndTransfer(uuid, accountFrom, accountTo, tokenFrom,
                                         tokenTo, sendType, tokenName, tokenIsOwnerToken, paths) {}
        function resetData() {}
        // local signals for testing function calls
        signal fetchSuggestedRoutesCalled()
    }

    readonly property SwapModalAdaptor swapAdaptor: SwapModalAdaptor {
        currencyStore: CurrenciesStore {}
        walletAssetsStore: WalletAssetsStoreMock {
            id: thisWalletAssetStore
            walletTokensStore: TokensStoreMock {
                tokenGroupsModel: TokenGroupsModel {}
                tokenGroupsForChainModel: TokenGroupsModel {
                    skipInitialLoad: true
                }
                tokenGroupsForChainToModel: TokenGroupsModel {
                    skipInitialLoad: true
                }
                searchResultModel: TokenGroupsModel {
                    skipInitialLoad: true
                    tokenGroupsForChainModel: thisWalletAssetStore.walletTokensStore.tokenGroupsForChainModel
                }
                _displayAssetsBelowBalanceThresholdDisplayAmountFunc: () => 0
            }
            readonly property var baseGroupedAccountAssetModel: GroupedAccountsAssetsModel {}
        }
        swapStore: root.swapStore
        swapFormData: root.swapFormData
        swapOutputData: SwapOutputData{}
        networksStore: NetworksStore {
            areTestNetworksEnabled: true
        }
    }

    property SwapInputParamsForm swapFormData: SwapInputParamsForm {}

    readonly property WalletAccountsSelectorAdaptor accountsSelectorAdaptor: WalletAccountsSelectorAdaptor {
        accounts: root.swapAdaptor.swapStore.accounts
        assetsModel: root.swapAdaptor.walletAssetsStore.baseGroupedAccountAssetModel
        tokenGroupsModel: root.swapAdaptor.walletAssetsStore.walletTokensStore.tokenGroupsModel
        filteredFlatNetworksModel: root.swapAdaptor.networksStore.activeNetworks

        selectedGroupKey: root.swapFormData.fromGroupKey
        selectedNetworkChainId: root.swapFormData.selectedNetworkChainId

        fnFormatCurrencyAmountFromBigInt: function(balance, symbol, decimals, options = null) {
            return root.swapAdaptor.currencyStore.formatCurrencyAmountFromBigInt(balance, symbol, decimals, options)
        }
    }

    Component {
        id: componentUnderTest
        SwapModal {
            swapInputParamsForm: root.swapFormData
            swapAdaptor: root.swapAdaptor
            buyEnabled: true
        }
    }

    SignalSpy {
        id: formValuesChanged
        target: root.swapFormData
        signalName: "formValuesChanged"
    }

    SignalSpy {
        id: fetchSuggestedRoutesCalled
        target: root.swapStore
        signalName: "fetchSuggestedRoutesCalled"
    }

    TestCase {
        name: "SwapModal"
        when: windowShown

        property SwapModal controlUnderTest: null

        // helper functions -------------------------------------------------------------

        function init() {
            root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(1)

            swapAdaptor.swapFormData = root.swapFormData
            controlUnderTest = createTemporaryObject(componentUnderTest, root, { swapInputParamsForm: root.swapFormData})
        }

        function cleanup() {
            root.swapAdaptor.reset()
            root.swapFormData.resetFormData()
            formValuesChanged.clear()
        }

        function launchAndVerfyModal() {
            formValuesChanged.clear()
            verify(!!controlUnderTest)

            if (root.swapFormData.selectedNetworkChainId === -1) {
                root.swapFormData.selectedNetworkChainId = 1
            }

            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened)
            tryVerify(() => controlUnderTest.enabled)
            // The token picker models are created lazily just after the modal opens
            // (kept off the open critical path); wait for them so the tests below can
            // read payPanel/receivePanel.tokenSelectorModel.
            const payPanel = findChild(controlUnderTest, "payPanel")
            tryVerify(() => !!payPanel && !!payPanel.tokenSelectorModel)
        }

        function closeAndVerfyModal() {
            verify(!!controlUnderTest)
            controlUnderTest.close()
            verify(!controlUnderTest.opened)
            formValuesChanged.clear()
            root.swapAdaptor.reset()
            root.swapFormData.resetFormData()
        }

        function getProcessedAccountsModel() {
            const model = root.accountsSelectorAdaptor.processedWalletAccounts
            verify(!!model)
            return model
        }

        function getPayAccountPill() {
            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)
            const pill = findChild(payPanel, "accountSelectorPill")
            verify(!!pill)
            return pill
        }

        function popupSearchRoot() {
            const overlay = controlUnderTest.Overlay.overlay
            verify(!!overlay)
            return overlay
        }

        function openFromAccountPopup() {
            const walletAccounts = getProcessedAccountsModel()
            tryVerify(() => walletAccounts.count > 0)
            const pill = getPayAccountPill()
            mouseClick(pill)
            const overlay = popupSearchRoot()
            let listView = null
            tryVerify(() => {
                const anyDelegate = findChild(overlay, walletAccounts.get(0).name)
                if (!anyDelegate)
                    return false
                listView = anyDelegate.ListView.view
                return !!listView
            }, 2000, "SwapFromAccountPopup did not open")
            return listView
        }

        function verifyLoadingAndNoErrorsState(payPanel, receivePanel) {
            // verify loading state was set and no errors currently
            verify(!root.swapAdaptor.validSwapProposalReceived)
            verify(root.swapAdaptor.swapProposalLoading, "root.swapAdaptor.swapProposalLoading is false with value: " + payPanel.value + " and key: " + payPanel.selectedHoldingId + " and chainID: " + root.swapFormData.selectedNetworkChainId + " and address: " + root.swapFormData.selectedAccountAddress)
            compare(root.swapAdaptor.swapOutputData.rawPaths, [])
            compare(root.swapAdaptor.swapOutputData.hasError, false)

            // verfy input and output panels
            verify(!payPanel.mainInputLoading)
            verify(payPanel.bottomTextLoading)
            compare(payPanel.selectedHoldingId, root.swapFormData.fromGroupKey)
            compare(payPanel.value, Number(root.swapFormData.fromTokenAmount))
            compare(payPanel.rawValue, SQUtils.AmountsArithmetic.fromNumber(root.swapFormData.fromTokenAmount, root.swapAdaptor.fromToken.decimals).toString())
            verify(payPanel.valueValid, "payPanel.valueValid is false with value: " + payPanel.value + " and key: " + payPanel.selectedHoldingId + " and chainID: " + root.swapFormData.selectedNetworkChainId + " and address: " + root.swapFormData.selectedAccountAddress)
            verify(receivePanel.mainInputLoading)
            verify(receivePanel.bottomTextLoading)
            verify(!receivePanel.interactive)
            compare(receivePanel.selectedHoldingId, root.swapFormData.toGroupKey)
            compare(receivePanel.value, 0)
            compare(receivePanel.rawValue, "0")
        }
        // end helper functions -------------------------------------------------------------

        function test_account_pill_default_account() {
            verify(!!controlUnderTest)

            launchAndVerfyModal()

            const pill = getPayAccountPill()
            const pillText = findChild(pill, "accountPillText")
            verify(!!pillText)
            const pillBackground = findChild(pill, "accountPillBackground")
            verify(!!pillBackground)

            let walletAccounts = getProcessedAccountsModel()
            /* using a for loop set different accounts as the selected account and
            check that the pay account pill reflects the correct name/emoji/color */
            for (let i = 0; i< walletAccounts.count; i++) {
                const accountToTest = walletAccounts.get(i)
                root.swapFormData.selectedAccountAddress = accountToTest.address

                tryCompare(pill, "name", accountToTest.name)
                compare(pill.emoji, accountToTest.emoji)
                compare(pill.colorId, accountToTest.colorId)
                compare(pill.address, accountToTest.address)

                compare(pillText.text, accountToTest.name)
                compare(pillBackground.color.toString().toUpperCase(),
                        Utils.getColorForId(controlUnderTest.Theme.palette, accountToTest.colorId).toString().toUpperCase())
            }
            closeAndVerfyModal()
        }

        function test_account_pill_doesnt_contain_watch_accounts() {
            // main input list from store should contian watch accounts
            let hasWatchAccount = false
            for(let i =0; i< swapStore.accounts.count; i++) {
                if(swapStore.accounts.get(i).walletType === Constants.watchWalletType) {
                    hasWatchAccount = true
                    break
                }
            }
            verify(!!hasWatchAccount)

            launchAndVerfyModal()

            const walletAccounts = getProcessedAccountsModel()
            let listHasWatchAccount = false
            for(let i =0; i< walletAccounts.count; i++) {
                if(walletAccounts.get(i).walletType === Constants.watchWalletType) {
                    listHasWatchAccount = true
                    break
                }
            }
            verify(!listHasWatchAccount)

            const listView = openFromAccountPopup()
            compare(listView.count, walletAccounts.count)

            closeAndVerfyModal()
        }

        function test_account_pill_list_items() {
            launchAndVerfyModal()
            let walletAccounts = getProcessedAccountsModel()

            const comboBoxList = openFromAccountPopup()
            verify(!!comboBoxList)
            waitForRendering(comboBoxList)
            compare(comboBoxList.count, walletAccounts.count)

            for(let i =0; i< comboBoxList.count; i++) {
                let delegateUnderTest = comboBoxList.itemAtIndex(i)
                verify(!!delegateUnderTest)
                let accountToBeTested = walletAccounts.get(i)
                let elidedAddress = SQUtils.Utils.elideAndFormatWalletAddress(accountToBeTested.address)
                compare(delegateUnderTest.title, accountToBeTested.name)
                compare(delegateUnderTest.subTitle, elidedAddress)
                compare(delegateUnderTest.asset.color.toString().toUpperCase(),
                        Utils.getColorForId(Theme.palette, accountToBeTested.colorId).toString().toUpperCase())
                compare(delegateUnderTest.asset.emoji, accountToBeTested.emoji)

                const walletAccountCurrencyBalance = findChild(delegateUnderTest, "walletAccountCurrencyBalance")
                verify(!!walletAccountCurrencyBalance)
                verify(walletAccountCurrencyBalance.text, LocaleUtils.currencyAmountToLocaleString(accountToBeTested.currencyBalance))

                if(root.swapFormData.selectedAccountAddress === accountToBeTested.address) {
                    verify(delegateUnderTest.color, Theme.palette.statusListItem.highlightColor)
                }
                else {
                    verify(delegateUnderTest.color, StatusColors.transparent)
                }
            }
            controlUnderTest.close()
        }

        function test_account_pill_after_setting_fromAsset() {
            // Launch popup
            launchAndVerfyModal()

            let comboBoxList = openFromAccountPopup()
            verify(!!comboBoxList)

            for(let i =0; i< comboBoxList.count; i++) {
                let delegateUnderTest = comboBoxList.itemAtIndex(i)
                verify(!delegateUnderTest.model.accountBalance)
            }

            root.swapFormData.selectedNetworkChainId = root.swapAdaptor.filteredFlatNetworksModel.get(0).chainId
            root.swapFormData.fromGroupKey = root.swapAdaptor.walletAssetsStore.walletTokensStore.tokenGroupsModel.get(0).key
            compare(controlUnderTest.swapInputParamsForm.selectedNetworkChainId, root.swapFormData.selectedNetworkChainId)
            compare(controlUnderTest.swapInputParamsForm.fromGroupKey, root.swapFormData.fromGroupKey)

            tryVerify(() => {
                for (let j = 0; j < comboBoxList.count; j++) {
                    const d = comboBoxList.itemAtIndex(j)
                    if (!d || !d.model.accountBalance || d.inlineTagModel !== 1)
                        return false
                }
                return true
            })

            for(let i =0; i< comboBoxList.count; i++) {
                let delegateUnderTest = comboBoxList.itemAtIndex(i)
                verify(!!delegateUnderTest)
                verify(!!delegateUnderTest.model.accountBalance)
                compare(delegateUnderTest.inlineTagModel, 1)

                const inlineTagDelegate_0 = findChild(delegateUnderTest, "inlineTagDelegate_0")
                verify(!!inlineTagDelegate_0)

                const balance = delegateUnderTest.model.accountBalance.balance

                compare(inlineTagDelegate_0.asset.name, Assets.svg(delegateUnderTest.model.accountBalance.iconUrl))
                compare(inlineTagDelegate_0.asset.color.toString().toUpperCase(), delegateUnderTest.model.accountBalance.chainColor.toString().toUpperCase())
                compare(inlineTagDelegate_0.titleText.color, balance === "0" ? Theme.palette.baseColor1 : Theme.palette.directColor1)

                let bigIntBalance = SQUtils.AmountsArithmetic.toNumber(balance, controlUnderTest.swapAdaptor.fromToken.decimals)
                compare(inlineTagDelegate_0.title, balance === "0" ? "0 %1".arg(controlUnderTest.swapAdaptor.fromToken.symbol)
                                                                   : root.swapAdaptor.currencyStore.formatCurrencyAmount(bigIntBalance, controlUnderTest.swapAdaptor.fromToken.symbol))
            }

            closeAndVerfyModal()
        }

        function test_account_pill_selection() {
            // Launch popup
            launchAndVerfyModal()

            let walletAccounts = getProcessedAccountsModel()

            const pill = getPayAccountPill()

            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)
            const amountToSendInput = findChild(payPanel, "amountToSendInput")
            verify(!!amountToSendInput)
            verify(amountToSendInput.cursorVisible)

            for(let i =0; i< walletAccounts.count; i++) {
                const expectedAccount = walletAccounts.get(i)

                const comboBoxList = openFromAccountPopup()
                verify(!!comboBoxList)

                let delegateUnderTest = comboBoxList.itemAtIndex(i)
                verify(!!delegateUnderTest)

                delegateUnderTest.clicked(delegateUnderTest.itemId ?? "", null)

                tryCompare(root.swapFormData, "selectedAccountAddress", expectedAccount.address)

                tryVerify(() => !findChild(popupSearchRoot(), expectedAccount.name), 1000, "SwapFromAccountPopup did not close")

                tryCompare(pill, "name", expectedAccount.name)
                compare(pill.emoji, expectedAccount.emoji)
                compare(pill.colorId, expectedAccount.colorId)

                tryVerify(() => amountToSendInput.cursorVisible)
            }
            closeAndVerfyModal()
        }

        function test_network_default_and_selection() {
            compare(root.swapFormData.selectedNetworkChainId, -1)

            // Launch popup
            launchAndVerfyModal()

            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)
            const amountToSendInput = findChild(payPanel, "amountToSendInput")
            verify(!!amountToSendInput)
            verify(amountToSendInput.cursorVisible)

            const networkBadge = findChild(payPanel, "networkBadge")
            verify(!!networkBadge)
            const networkBadgeText = findChild(payPanel, "networkBadgeText")
            verify(!!networkBadgeText)

            compare(root.swapFormData.selectedNetworkChainId, 1)
            compare(root.swapAdaptor.filteredFlatNetworksModel.get(0).chainId, 560048 /*Hoodi*/)

            const activeNetworks = root.swapAdaptor.networksStore.activeNetworks

            for (let i=0; i<activeNetworks.count; i++) {
                const networkItem = activeNetworks.get(i)
                root.swapFormData.selectedNetworkChainId = networkItem.chainId

                tryCompare(root.swapFormData, "selectedNetworkChainId", networkItem.chainId)
                verify(networkBadge.visible)
                tryCompare(networkBadgeText, "text", networkItem.chainName)
            }
            closeAndVerfyModal()
        }

        function test_network_and_account_header_items() {
            // Launch popup
            launchAndVerfyModal()

            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)
            const networkBadgeText = findChild(payPanel, "networkBadgeText")
            verify(!!networkBadgeText)

            root.swapFormData.fromGroupKey = root.swapAdaptor.walletAssetsStore.walletTokensStore.tokenGroupsModel.get(0).key

            const activeNetworks = root.swapAdaptor.networksStore.activeNetworks

            const comboBoxList = openFromAccountPopup()
            verify(!!comboBoxList)

            for (let i=0; i<activeNetworks.count; i++) {
                let networkModelItem = activeNetworks.get(i)

                root.swapFormData.selectedNetworkChainId = networkModelItem.chainId
                tryCompare(networkBadgeText, "text", networkModelItem.chainName)

                waitForRendering(comboBoxList)

                for(let j =0; j< comboBoxList.count; j++) {
                    let accountDelegateUnderTest = comboBoxList.itemAtIndex(j)
                    verify(!!accountDelegateUnderTest)
                    waitForItemPolished(accountDelegateUnderTest)
                    const inlineTagDelegate_0 = findChild(accountDelegateUnderTest, "inlineTagDelegate_0")
                    verify(!!inlineTagDelegate_0)

                    let balancesModel = SQUtils.ModelUtils.getByKey(root.swapAdaptor.walletAssetsStore.baseGroupedAccountAssetModel, "key", root.swapFormData.fromGroupKey).balances
                    verify(!!balancesModel)
                    let filteredBalances = SQUtils.ModelUtils.modelToArray(balancesModel).filter(balances => balances.chainId === root.swapFormData.selectedNetworkChainId).filter(balances => balances.account === accountDelegateUnderTest.model.address)
                    verify(!!filteredBalances)
                    let accountBalance = filteredBalances.length > 0 ? filteredBalances[0]: { balance: "0", iconUrl: networkModelItem.iconUrl, chainColor: networkModelItem.chainColor}
                    verify(!!accountBalance)
                    let fromToken = SQUtils.ModelUtils.getByKey(root.swapAdaptor.walletAssetsStore.walletTokensStore.tokenGroupsModel, "key", root.swapFormData.fromGroupKey)
                    verify(!!fromToken)
                    let bigIntBalance = SQUtils.AmountsArithmetic.toNumber(accountBalance.balance, fromToken.decimals)

                    tryCompare(inlineTagDelegate_0.asset, "name", Assets.svg(networkModelItem.iconUrl))
                    compare(inlineTagDelegate_0.asset.color.toString().toUpperCase(), networkModelItem.chainColor.toString().toUpperCase())
                    tryCompare(inlineTagDelegate_0, "title", bigIntBalance === 0 ? "0 %1".arg(fromToken.symbol)
                                                                           : root.swapAdaptor.currencyStore.formatCurrencyAmount(bigIntBalance, fromToken.symbol))
                }
            }
            root.swapFormData.selectedNetworkChainId = -1
            closeAndVerfyModal()
        }

        function test_edit_slippage() {
            // Launch popup
            launchAndVerfyModal()

            const slippageButton = findChild(controlUnderTest, "slippageButton")
            verify(!!slippageButton)
            verify(slippageButton.checkable)

            const editSlippagePanel = findChild(controlUnderTest, "editSlippagePanel")
            verify(!!editSlippagePanel)
            verify(!editSlippagePanel.visible)
            verify(!slippageButton.checked)

            root.swapAdaptor.validSwapProposalReceived = true
            verify(slippageButton.visible)
            compare(slippageButton.text, "%1%".arg(LocaleUtils.numberToLocaleString(root.swapFormData.selectedSlippage)))
            compare(slippageButton.text, "%1%".arg(0.5))

            waitForRendering(slippageButton)
            mouseClick(slippageButton)
            tryVerify(() => slippageButton.checked, 2000, "slippage button did not toggle")
            verify(editSlippagePanel.visible)

            const slippageSelector = findChild(editSlippagePanel, "slippageSelector")
            verify(!!slippageSelector)

            verify(slippageSelector.valid)
            compare(slippageSelector.value, 0.5)

            const buttonsRepeater = findChild(slippageSelector, "buttonsRepeater")
            verify(!!buttonsRepeater)
            waitForRendering(buttonsRepeater)

            for(let i =0; i< buttonsRepeater.count; i++) {
                let buttonUnderTest = buttonsRepeater.itemAt(i)
                verify(!!buttonUnderTest)

                // the mouseClick(buttonUnderTest) doesnt seem to work
                buttonUnderTest.clicked()

                verify(slippageSelector.valid)
                compare(slippageSelector.value, buttonUnderTest.value)

                tryCompare(slippageButton, "text", "%1%".arg(LocaleUtils.numberToLocaleString(buttonUnderTest.value)))
            }

            const signButton = findChild(controlUnderTest, "signButton")
            verify(!!signButton)
            verify(signButton.enabled)
        }

        function test_modal_swap_proposal_setup() {
            root.swapAdaptor.reset()

            // Launch popup
            launchAndVerfyModal()

            waitForItemPolished(controlUnderTest.contentItem)

            const signButton = findChild(controlUnderTest, "signButton")
            verify(!!signButton)

            const errorTag = findChild(controlUnderTest, "errorTag")
            verify(!!errorTag)

            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)

            const receivePanel = findChild(controlUnderTest, "receivePanel")
            verify(!!receivePanel)

            verify(!signButton.interactive)
            verify(!errorTag.visible)

            // set input values in the form correctly
            root.swapFormData.fromGroupKey = sttGroupKey
            formValuesChanged.wait()
            root.swapFormData.toGroupKey = root.swapAdaptor.walletAssetsStore.walletTokensStore.tokenGroupsModel.get(1).key
            root.swapFormData.fromTokenAmount = "0.001"
            waitForRendering(receivePanel)
            formValuesChanged.wait()
            root.swapFormData.selectedNetworkChainId = 11155420
            root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(root.swapFormData.selectedNetworkChainId)
            formValuesChanged.wait()
            root.swapFormData.selectedAccountAddress = "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            formValuesChanged.wait()

            // wait for fetchSuggestedRoutes function to be called
            fetchSuggestedRoutesCalled.wait()

            // verify loading state was set and no errors currently
            verifyLoadingAndNoErrorsState(payPanel, receivePanel)

            // emit event that no routes were found with unknown error
            const txRoutes = root.dummySwapTransactionRoutes.txNoRoutes
            txRoutes.uuid = root.swapAdaptor.uuid
            root.swapStore.suggestedRoutesReady(txRoutes, "NO_ROUTES", "No routes found")

            // verify loading state was removed and that error was displayed
            verify(!root.swapAdaptor.validSwapProposalReceived)
            verify(!root.swapAdaptor.swapProposalLoading)
            compare(root.swapAdaptor.swapOutputData.fromTokenAmount, "")
            compare(root.swapAdaptor.swapOutputData.toTokenAmount, "")
            compare(root.swapAdaptor.swapOutputData.totalFees, 0)
            compare(root.swapAdaptor.swapOutputData.approvalNeeded, false)
            compare(root.swapAdaptor.swapOutputData.hasError, true)
            verify(errorTag.visible)
            verify(errorTag.text, qsTr("An error has occured, please try again"))
            verify(!signButton.interactive)
            compare(signButton.text, qsTr("Confirm swap"))

            // verfy input and output panels
            verify(!payPanel.mainInputLoading)
            verify(!payPanel.bottomTextLoading)
            verify(!receivePanel.mainInputLoading)
            verify(!receivePanel.bottomTextLoading)
            verify(!receivePanel.interactive)
            compare(receivePanel.selectedHoldingId, root.swapFormData.toGroupKey)
            compare(receivePanel.value, 0)
            compare(receivePanel.rawValue, "0")

            // edit some params to retry swap
            root.swapFormData.fromTokenAmount = "0.00011"
            waitForRendering(receivePanel)
            formValuesChanged.wait()

            // wait for fetchSuggestedRoutes function to be called
            fetchSuggestedRoutesCalled.wait()

            // verify loading state was set and no errors currently
            verifyLoadingAndNoErrorsState(payPanel, receivePanel)

            // emit event that no routes were found due to not enough token balance
            txRoutes.uuid = root.swapAdaptor.uuid
            root.swapStore.suggestedRoutesReady(txRoutes, Constants.routerErrorCodes.router.errNotEnoughTokenBalance, "errNotEnoughTokenBalance")

            // verify loading state was removed and that error was displayed
            verify(!root.swapAdaptor.validSwapProposalReceived)
            verify(!root.swapAdaptor.swapProposalLoading)
            compare(root.swapAdaptor.swapOutputData.fromTokenAmount, "")
            compare(root.swapAdaptor.swapOutputData.toTokenAmount, "")
            compare(root.swapAdaptor.swapOutputData.totalFees, 0)
            compare(root.swapAdaptor.swapOutputData.approvalNeeded, false)
            compare(root.swapAdaptor.swapOutputData.hasError, true)
            verify(errorTag.visible)
            verify(errorTag.text, qsTr("Insufficient funds for swap"))
            verify(!signButton.interactive)
            compare(signButton.text, qsTr("Confirm swap"))

            // verfy input and output panels
            verify(!payPanel.mainInputLoading)
            verify(!payPanel.bottomTextLoading)
            verify(!receivePanel.mainInputLoading)
            verify(!receivePanel.bottomTextLoading)
            verify(!receivePanel.interactive)
            compare(receivePanel.selectedHoldingId, root.swapFormData.toGroupKey)
            compare(receivePanel.value, 0)
            compare(receivePanel.rawValue, "0")

            // edit some params to retry swap
            root.swapFormData.fromTokenAmount = "0.00012"
            waitForRendering(receivePanel)
            formValuesChanged.wait()

            // wait for fetchSuggestedRoutes function to be called
            fetchSuggestedRoutesCalled.wait()

            // verify loading state was set and no errors currently
            verifyLoadingAndNoErrorsState(payPanel, receivePanel)

            // emit event that no routes were found due to not enough eth balance
            txRoutes.uuid = root.swapAdaptor.uuid
            root.swapStore.suggestedRoutesReady(txRoutes, Constants.routerErrorCodes.router.errNotEnoughNativeBalance, "errNotEnoughNativeBalance")

            // verify loading state was removed and that error was displayed
            verify(!root.swapAdaptor.validSwapProposalReceived)
            verify(!root.swapAdaptor.swapProposalLoading)
            compare(root.swapAdaptor.swapOutputData.fromTokenAmount, "")
            compare(root.swapAdaptor.swapOutputData.toTokenAmount, "")
            compare(root.swapAdaptor.swapOutputData.totalFees, 0)
            compare(root.swapAdaptor.swapOutputData.approvalNeeded, false)
            compare(root.swapAdaptor.swapOutputData.hasError, true)
            verify(errorTag.visible)
            verify(errorTag.text, qsTr("Not enough ETH to pay gas fees"))
            verify(!signButton.interactive)
            compare(signButton.text, qsTr("Confirm swap"))

            // verfy input and output panels
            verify(!payPanel.mainInputLoading)
            verify(!payPanel.bottomTextLoading)
            verify(!receivePanel.mainInputLoading)
            verify(!receivePanel.bottomTextLoading)
            verify(!receivePanel.interactive)
            compare(receivePanel.selectedHoldingId, root.swapFormData.toGroupKey)
            compare(receivePanel.value, 0)
            compare(receivePanel.rawValue, "0")

            // edit some params to retry swap
            root.swapFormData.fromTokenAmount = "0.00013"
            waitForRendering(receivePanel)
            formValuesChanged.wait()

            // wait for fetchSuggestedRoutes function to be called
            fetchSuggestedRoutesCalled.wait()

            // verify loading state was set and no errors currently
            verifyLoadingAndNoErrorsState(payPanel, receivePanel)

            // emit event that no routes were found due to price timeout
            txRoutes.uuid = root.swapAdaptor.uuid
            root.swapStore.suggestedRoutesReady(txRoutes, Constants.routerErrorCodes.processor.errPriceTimeout, "errPriceTimeout")

            // verify loading state was removed and that error was displayed
            verify(!root.swapAdaptor.validSwapProposalReceived)
            verify(!root.swapAdaptor.swapProposalLoading)
            compare(root.swapAdaptor.swapOutputData.fromTokenAmount, "")
            compare(root.swapAdaptor.swapOutputData.toTokenAmount, "")
            compare(root.swapAdaptor.swapOutputData.totalFees, 0)
            compare(root.swapAdaptor.swapOutputData.approvalNeeded, false)
            compare(root.swapAdaptor.swapOutputData.hasError, true)
            verify(errorTag.visible)
            verify(errorTag.text, qsTr("Fetching the price took longer than expected. Please, try again later."))
            verify(!signButton.interactive)
            compare(signButton.text, qsTr("Confirm swap"))

            // verfy input and output panels
            verify(!payPanel.mainInputLoading)
            verify(!payPanel.bottomTextLoading)
            verify(!receivePanel.mainInputLoading)
            verify(!receivePanel.bottomTextLoading)
            verify(!receivePanel.interactive)
            compare(receivePanel.selectedHoldingId, root.swapFormData.toGroupKey)
            compare(receivePanel.value, 0)
            compare(receivePanel.rawValue, "0")

            // edit some params to retry swap
            root.swapFormData.fromTokenAmount = "0.00014"
            waitForRendering(receivePanel)
            formValuesChanged.wait()

            // wait for fetchSuggestedRoutes function to be called
            fetchSuggestedRoutesCalled.wait()

            // verify loading state was set and no errors currently
            verifyLoadingAndNoErrorsState(payPanel, receivePanel)

            // emit event that no routes were found due to not enough liquidity
            txRoutes.uuid = root.swapAdaptor.uuid
            root.swapStore.suggestedRoutesReady(txRoutes, Constants.routerErrorCodes.processor.errNotEnoughLiquidity, "errNotEnoughLiquidity")

            // verify loading state was removed and that error was displayed
            verify(!root.swapAdaptor.validSwapProposalReceived)
            verify(!root.swapAdaptor.swapProposalLoading)
            compare(root.swapAdaptor.swapOutputData.fromTokenAmount, "")
            compare(root.swapAdaptor.swapOutputData.toTokenAmount, "")
            compare(root.swapAdaptor.swapOutputData.totalFees, 0)
            compare(root.swapAdaptor.swapOutputData.approvalNeeded, false)
            compare(root.swapAdaptor.swapOutputData.hasError, true)
            verify(errorTag.visible)
            verify(errorTag.text, qsTr("Not enough liquidity. Lower token amount or try again later."))
            verify(!signButton.interactive)
            compare(signButton.text, qsTr("Confirm swap"))

            // verfy input and output panels
            verify(!payPanel.mainInputLoading)
            verify(!payPanel.bottomTextLoading)
            verify(!receivePanel.mainInputLoading)
            verify(!receivePanel.bottomTextLoading)
            verify(!receivePanel.interactive)
            compare(receivePanel.selectedHoldingId, root.swapFormData.toGroupKey)
            compare(receivePanel.value, 0)
            compare(receivePanel.rawValue, "0")

            // edit some params to retry swap
            root.swapFormData.fromTokenAmount = "0.00015"
            waitForRendering(receivePanel)
            formValuesChanged.wait()
            // verify loading state was set and no errors currently
            verifyLoadingAndNoErrorsState(payPanel, receivePanel)

            // emit event with route that needs no approval
            const txHasRouteNoApproval = root.dummySwapTransactionRoutes.txHasRouteNoApproval
            txHasRouteNoApproval.uuid = root.swapAdaptor.uuid
            root.swapStore.suggestedRoutesReady(txHasRouteNoApproval, "", "")

            // verify loading state removed and data is displayed as expected on the Modal
            verify(root.swapAdaptor.validSwapProposalReceived)
            verify(!root.swapAdaptor.swapProposalLoading)
            compare(root.swapAdaptor.swapOutputData.fromTokenAmount, "")
            compare(root.swapAdaptor.swapOutputData.toTokenAmount,
                    SQUtils.AmountsArithmetic.div(
                        SQUtils.AmountsArithmetic.fromString(txHasRouteNoApproval.amountToReceive),
                        SQUtils.AmountsArithmetic.fromNumber(1, root.swapAdaptor.toToken.decimals)
                        ).toString())

            // calculation needed for total fees
            let gasTimeEstimate = txHasRouteNoApproval.gasTimeEstimate
            let totalTokenFeesInFiat = gasTimeEstimate.totalTokenFees * root.swapAdaptor.fromToken.marketDetails.currencyPrice.amount
            let totalFees = root.swapAdaptor.currencyStore.getFiatValue(gasTimeEstimate.totalFeesInNativeCrypto, Constants.ethToken) + totalTokenFeesInFiat

            compare(root.swapAdaptor.swapOutputData.totalFees, totalFees)
            compare(root.swapAdaptor.swapOutputData.approvalNeeded, false)
            compare(root.swapAdaptor.swapOutputData.hasError, false)
            verify(!errorTag.visible, "error tag visible with text: " + errorTag.text)
            verify(signButton.enabled)
            compare(signButton.text, qsTr("Confirm swap"))

            // verfy input and output panels
            waitForRendering(receivePanel)
            verify(payPanel.valueValid)
            verify(!payPanel.mainInputLoading)
            verify(!payPanel.bottomTextLoading)
            verify(!receivePanel.mainInputLoading)
            verify(!receivePanel.bottomTextLoading)
            verify(!receivePanel.interactive)
            compare(receivePanel.selectedHoldingId, root.swapFormData.toGroupKey)
            compare(receivePanel.value, root.swapStore.getWei2Eth(txHasRouteNoApproval.amountToReceive, root.swapAdaptor.toToken.decimals))
            compare(receivePanel.rawValue,
                    SQUtils.AmountsArithmetic.times(
                        SQUtils.AmountsArithmetic.fromString(root.swapAdaptor.swapOutputData.toTokenAmount),
                        SQUtils.AmountsArithmetic.fromNumber(1, root.swapAdaptor.toToken.decimals)
                        ).toFixed())

            // edit some params to retry swap
            root.swapFormData.fromTokenAmount = "0.012"
            waitForRendering(receivePanel)
            formValuesChanged.wait()

            // wait for fetchSuggestedRoutes function to be called
            fetchSuggestedRoutesCalled.wait()

            // verify loading state was set and no errors currently
            verifyLoadingAndNoErrorsState(payPanel, receivePanel)

            // emit event with route that needs no approval
            let txRoutes2 = root.dummySwapTransactionRoutes.txHasRoutesApprovalNeeded
            txRoutes2.uuid = root.swapAdaptor.uuid
            root.swapStore.suggestedRoutesReady(txRoutes2, "", "")

            // verify loading state removed and data ius displayed as expected on the Modal
            verify(root.swapAdaptor.validSwapProposalReceived)
            verify(!root.swapAdaptor.swapProposalLoading)
            compare(root.swapAdaptor.swapOutputData.fromTokenAmount, "")
            compare(root.swapAdaptor.swapOutputData.toTokenAmount, SQUtils.AmountsArithmetic.div(
                        SQUtils.AmountsArithmetic.fromString(txRoutes2.amountToReceive),
                        SQUtils.AmountsArithmetic.fromNumber(1, root.swapAdaptor.toToken.decimals)).toString())

            // calculation needed for total fees
            gasTimeEstimate = txRoutes2.gasTimeEstimate
            totalTokenFeesInFiat = gasTimeEstimate.totalTokenFees * root.swapAdaptor.fromToken.marketDetails.currencyPrice.amount
            totalFees = root.swapAdaptor.currencyStore.getFiatValue(gasTimeEstimate.totalFeesInNativeCrypto, Constants.ethToken) + totalTokenFeesInFiat

            compare(root.swapAdaptor.swapOutputData.totalFees, totalFees)
            compare(root.swapAdaptor.swapOutputData.approvalNeeded, true)
            compare(root.swapAdaptor.swapOutputData.hasError, false)

            // fee-reservation interplay: the adaptor derives maxFeesToReserveRaw
            // from the best path's max gas fees (independent of owned balance)
            let bestPath = SQUtils.ModelUtils.get(txRoutes2.suggestedRoutes, 0, "route")
            const totalMaxFees = Math.ceil(bestPath.gasFees.maxFeePerGasM) * bestPath.gasAmount
            const totalMaxFeesInEth = SQUtils.AmountsArithmetic.div(
                                        SQUtils.AmountsArithmetic.fromString(totalMaxFees),
                                        SQUtils.AmountsArithmetic.fromNumber(1, 9))
            const amountToReserve = SQUtils.AmountsArithmetic.times(totalMaxFeesInEth, SQUtils.AmountsArithmetic.fromExponent(18)).toString()
            compare(root.swapAdaptor.swapOutputData.maxFeesToReserveRaw, amountToReserve)
            verify(!errorTag.visible)
            verify(signButton.enabled)
            compare(signButton.text, qsTr("Approve %1").arg(root.swapAdaptor.fromToken.symbol))

            // verfy input and output panels
            waitForRendering(receivePanel)
            verify(payPanel.valueValid)
            verify(!payPanel.mainInputLoading)
            verify(!payPanel.bottomTextLoading)
            verify(!receivePanel.mainInputLoading)
            verify(!receivePanel.bottomTextLoading)
            verify(!receivePanel.interactive)
            compare(receivePanel.selectedHoldingId, root.swapFormData.toGroupKey)
            compare(receivePanel.value, root.swapStore.getWei2Eth(txRoutes2.amountToReceive, root.swapAdaptor.toToken.decimals))
            compare(receivePanel.rawValue,
                    SQUtils.AmountsArithmetic.times(
                        SQUtils.AmountsArithmetic.fromString(root.swapAdaptor.swapOutputData.toTokenAmount),
                        SQUtils.AmountsArithmetic.fromNumber(1, root.swapAdaptor.toToken.decimals)
                        ).toFixed())
        }

        function test_modal_pay_input_default() {
            if (root.swapFormData.selectedNetworkChainId === -1) {
                root.swapFormData.selectedNetworkChainId = 1
            }
            root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(root.swapFormData.selectedNetworkChainId)

            // Launch popup
            launchAndVerfyModal()

            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)
            const amountToSendInput = findChild(payPanel, "amountToSendInput")
            verify(!!amountToSendInput)
            const bottomItemText = findChild(payPanel, "bottomItemText")
            verify(!!bottomItemText)
            const holdingSelector = findChild(payPanel, "holdingSelector")
            verify(!!holdingSelector)
            const balanceLine = findChild(payPanel, "balanceLine")
            verify(!!balanceLine)
            const tokenSelectorContentItemText = findChild(payPanel, "tokenSelectorContentItemText")
            verify(!!tokenSelectorContentItemText)
            const payTokenModel = payPanel.tokenSelectorModel
            verify(!!payTokenModel)
            const defaultToken = SQUtils.ModelUtils.getByKey(payTokenModel, "key", root.swapFormData.fromGroupKey)
            verify(!!defaultToken)

            waitForRendering(controlUnderTest.contentItem)

            // check default states for the from input selector
            verify(amountToSendInput.interactive)
            compare(amountToSendInput.text, "")
            verify(amountToSendInput.cursorVisible)
            compare(amountToSendInput.placeholderText, LocaleUtils.numberToLocaleString(0))
            compare(bottomItemText.text, root.swapAdaptor.currencyStore.formatCurrencyAmount(0, root.swapAdaptor.currencyStore.currentCurrency))
            compare(tokenSelectorContentItemText.text, defaultToken.symbol)
            verify(balanceLine.visible)
            compare(payPanel.selectedHoldingId, root.swapFormData.fromGroupKey)
            compare(payPanel.value, 0)
            compare(payPanel.rawValue, "0")
            verify(!payPanel.valueValid)

            closeAndVerfyModal()
        }

        function test_modal_pay_input_presetValues() {
            // try setting value before popup is launched and check values
            let valueToExchange = 0.001
            let valueToExchangeString = valueToExchange.toString()

            let walletAccounts = getProcessedAccountsModel()

            root.swapFormData.selectedAccountAddress = walletAccounts.get(0).address
            root.swapFormData.selectedNetworkChainId = root.swapAdaptor.filteredFlatNetworksModel.get(0).chainId
            root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(root.swapFormData.selectedNetworkChainId)
            root.swapFormData.fromGroupKey = sttGroupKey
            root.swapFormData.fromTokenAmount = valueToExchangeString

            // Launch popup
            launchAndVerfyModal()

            waitForItemPolished(controlUnderTest.contentItem)

            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)
            waitForRendering(payPanel)
            const amountToSendInput = findChild(payPanel, "amountToSendInput")
            verify(!!amountToSendInput)
            const bottomItemText = findChild(payPanel, "bottomItemText")
            verify(!!bottomItemText)
            const holdingSelector = findChild(payPanel, "holdingSelector")
            verify(!!holdingSelector)
            const balanceLine = findChild(payPanel, "balanceLine")
            verify(!!balanceLine)
            const balanceCryptoText = findChild(payPanel, "balanceCryptoText")
            verify(!!balanceCryptoText)
            const tokenSelectorContentItemText = findChild(payPanel, "tokenSelectorContentItemText")
            verify(!!tokenSelectorContentItemText)
            const tokenSelectorIcon = findChild(payPanel, "tokenSelectorIcon")
            verify(!!tokenSelectorIcon)
            const payTokenModel = payPanel.tokenSelectorModel
            verify(!!payTokenModel)

            const expectedToken = SQUtils.ModelUtils.getByKey(payTokenModel, "key", sttGroupKey)
            verify(amountToSendInput.interactive)
            tryCompare(amountToSendInput, "text", valueToExchangeString)
            compare(amountToSendInput.placeholderText, LocaleUtils.numberToLocaleString(0))
            tryCompare(amountToSendInput, "cursorVisible", true)
            tryCompare(bottomItemText, "text", root.swapAdaptor.currencyStore.formatCurrencyAmount(valueToExchange * expectedToken.cryptoPrice, root.swapAdaptor.currencyStore.currentCurrency))
            tryCompare(tokenSelectorContentItemText, "text", expectedToken.symbol)
            const expectedIconSource = expectedToken.logoUri || Constants.tokenIcon(expectedToken.symbol)
            compare(tokenSelectorIcon.image.source, expectedIconSource)
            verify(tokenSelectorIcon.visible)
            verify(balanceLine.visible)
            compare(balanceCryptoText.text, root.swapAdaptor.currencyStore.formatCurrencyAmount(payPanel.maxCryptoBalance, expectedToken.symbol, {noSymbol: true, roundingMode: LocaleUtils.RoundingMode.Down}))
            compare(payPanel.maxSafeCryptoValue, WalletUtils.calculateMaxSafeSendAmount(payPanel.maxCryptoBalance, expectedToken.symbol, root.swapFormData.selectedNetworkChainId))
            compare(payPanel.selectedHoldingId, expectedToken.key)
            compare(payPanel.value, valueToExchange)
            compare(payPanel.rawValue, SQUtils.AmountsArithmetic.fromNumber(valueToExchangeString, expectedToken.decimals).toString())
            tryCompare(payPanel, "valueValid", expectedToken.currentBalance > 0)

            closeAndVerfyModal()
        }

        function test_modal_pay_input_wrong_value_1() {
            let walletAccounts = getProcessedAccountsModel()

            let invalidValues = ["ABC", "0.0.010201", "12PASA", "100,9.01"]
            for (let i =0; i<invalidValues.length; i++) {
                let invalidValue = invalidValues[i]
                // try setting value before popup is launched and check values
                root.swapFormData.selectedAccountAddress = walletAccounts.get(0).address
                root.swapFormData.selectedNetworkChainId = root.swapAdaptor.filteredFlatNetworksModel.get(0).chainId
                root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(root.swapFormData.selectedNetworkChainId)
                root.swapFormData.fromGroupKey = ""
                root.swapFormData.fromTokenAmount = invalidValue

                // Launch popup
                launchAndVerfyModal()

                const payPanel = findChild(controlUnderTest, "payPanel")
                verify(!!payPanel)
                const amountToSendInput = findChild(payPanel, "amountToSendInput")
                verify(!!amountToSendInput)
                const bottomItemText = findChild(payPanel, "bottomItemText")
                verify(!!bottomItemText)
                const holdingSelector = findChild(payPanel, "holdingSelector")
                verify(!!holdingSelector)
                const balanceLine = findChild(payPanel, "balanceLine")
                verify(!!balanceLine)

                waitForRendering(payPanel)
                const payTokenModel = payPanel.tokenSelectorModel
                verify(!!payTokenModel)
                verify(amountToSendInput.interactive)
                compare(amountToSendInput.placeholderText, LocaleUtils.numberToLocaleString(0))
                verify(amountToSendInput.cursorVisible)
                compare(bottomItemText.text, root.swapAdaptor.currencyStore.formatCurrencyAmount(0, root.swapAdaptor.currencyStore.currentCurrency))
                const tokenSelectorContentItemText = findChild(payPanel, "tokenSelectorContentItemText")
                verify(!!tokenSelectorContentItemText)
                const defaultTokenEntry = SQUtils.ModelUtils.getByKey(payTokenModel, "key", root.swapFormData.defaultFromGroupKey)
                compare(tokenSelectorContentItemText.text, defaultTokenEntry ? defaultTokenEntry.symbol : "")
                verify(balanceLine.visible)
                compare(payPanel.selectedHoldingId, root.swapFormData.defaultFromGroupKey)
                compare(payPanel.value, 0)
                compare(payPanel.rawValue, SQUtils.AmountsArithmetic.fromNumber("0", 0).toString())
                verify(!payPanel.valueValid)

                closeAndVerfyModal()
            }
        }

        function test_modal_pay_input_wrong_value_2() {
            let walletAccounts = getProcessedAccountsModel()

            // try setting value before popup is launched and check values
            let valueToExchange = 100
            let valueToExchangeString = valueToExchange.toString()
            root.swapFormData.selectedAccountAddress = walletAccounts.get(0).address
            root.swapFormData.selectedNetworkChainId = root.swapAdaptor.filteredFlatNetworksModel.get(0).chainId
            root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(root.swapFormData.selectedNetworkChainId)
            root.swapFormData.fromGroupKey = sttGroupKey
            root.swapFormData.fromTokenAmount = valueToExchangeString

            // Launch popup
            launchAndVerfyModal()

            waitForItemPolished(controlUnderTest.contentItem)

            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)
            waitForRendering(payPanel)
            const amountToSendInput = findChild(payPanel, "amountToSendInput")
            verify(!!amountToSendInput)
            const bottomItemText = findChild(payPanel, "bottomItemText")
            verify(!!bottomItemText)
            const holdingSelector = findChild(payPanel, "holdingSelector")
            verify(!!holdingSelector)
            const balanceLine = findChild(payPanel, "balanceLine")
            verify(!!balanceLine)
            const balanceCryptoText = findChild(payPanel, "balanceCryptoText")
            verify(!!balanceCryptoText)
            const tokenSelectorContentItemText = findChild(payPanel, "tokenSelectorContentItemText")
            verify(!!tokenSelectorContentItemText)
            const tokenSelectorIcon = findChild(payPanel, "tokenSelectorIcon")
            verify(!!tokenSelectorIcon)
            const payTokenModel = payPanel.tokenSelectorModel
            verify(!!payTokenModel)
            const expectedToken = SQUtils.ModelUtils.getByKey(payTokenModel, "key", sttGroupKey)
            verify(amountToSendInput.interactive)
            compare(amountToSendInput.text, valueToExchangeString)
            compare(amountToSendInput.placeholderText, LocaleUtils.numberToLocaleString(0))
            tryCompare(amountToSendInput, "cursorVisible", true)
            tryCompare(bottomItemText, "text", root.swapAdaptor.currencyStore.formatCurrencyAmount(valueToExchange * expectedToken.cryptoPrice, root.swapAdaptor.currencyStore.currentCurrency))
            compare(tokenSelectorContentItemText.text, expectedToken.symbol)
            const expectedIconSource = expectedToken.logoUri || Constants.tokenIcon(expectedToken.symbol)
            compare(tokenSelectorIcon.image.source, expectedIconSource)
            verify(tokenSelectorIcon.visible)
            verify(balanceLine.visible)
            compare(balanceCryptoText.text, root.swapAdaptor.currencyStore.formatCurrencyAmount(payPanel.maxCryptoBalance, expectedToken.symbol, {noSymbol: true, roundingMode: LocaleUtils.RoundingMode.Down}))
            compare(payPanel.maxSafeCryptoValue, WalletUtils.calculateMaxSafeSendAmount(payPanel.maxCryptoBalance, expectedToken.symbol, root.swapFormData.selectedNetworkChainId))
            compare(payPanel.selectedHoldingId, expectedToken.key)
            compare(payPanel.value, valueToExchange)
            compare(payPanel.rawValue, SQUtils.AmountsArithmetic.fromNumber(valueToExchangeString, expectedToken.decimals).toString())
            // NOTE: the amount-exceeds-owned-balance -> invalid assertion is dropped
            // here — it needs the producer's per-account owned-balance join, which the
            // storybook stub can't reproduce; covered by the Nim model/builder tests.

            closeAndVerfyModal()
        }

        function test_modal_receive_input_default() {
            if (root.swapFormData.selectedNetworkChainId === -1) {
                root.swapFormData.selectedNetworkChainId = 1
            }
            root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(root.swapFormData.selectedNetworkChainId)

            // Launch popup
            launchAndVerfyModal()

            const receivePanel = findChild(controlUnderTest, "receivePanel")
            verify(!!receivePanel)
            waitForRendering(receivePanel)
            const amountToSendInput = findChild(receivePanel, "amountToSendInput")
            verify(!!amountToSendInput)
            const bottomItemText = findChild(receivePanel, "bottomItemText")
            verify(!!bottomItemText)
            const holdingSelector = findChild(receivePanel, "holdingSelector")
            verify(!!holdingSelector)
            const tokenSelectorContentItemText = findChild(receivePanel, "tokenSelectorContentItemText")
            verify(!!tokenSelectorContentItemText)

            // check default states for the from input selector
            compare(amountToSendInput.text, "")
            // TODO: this should be come interactive under https://github.com/status-im/status-desktop/issues/15095
            verify(!amountToSendInput.interactive)
            verify(!amountToSendInput.cursorVisible)
            compare(amountToSendInput.placeholderText, LocaleUtils.numberToLocaleString(0))
            tryCompare(bottomItemText, "text", root.swapAdaptor.currencyStore.formatCurrencyAmount(0, root.swapAdaptor.currencyStore.currentCurrency))
            compare(tokenSelectorContentItemText.text, Constants.ethToken)
            compare(receivePanel.selectedHoldingId, Constants.ethGroupKey)
            compare(receivePanel.value, 0)
            compare(receivePanel.rawValue, "0")
            verify(!receivePanel.valueValid)

            closeAndVerfyModal()
        }

        function test_modal_receive_input_presetValues() {
            let walletAccounts = getProcessedAccountsModel()

            let valueToReceive = 0.001
            let valueToReceiveString = valueToReceive.toString()
            // try setting value before popup is launched and check values
            root.swapFormData.selectedAccountAddress = walletAccounts.get(0).address
            root.swapFormData.selectedNetworkChainId = 11155420
            root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(root.swapFormData.selectedNetworkChainId)
            root.swapFormData.toGroupKey = sttGroupKey
            root.swapFormData.toTokenAmount = valueToReceiveString

            // Launch popup
            launchAndVerfyModal()

            waitForItemPolished(controlUnderTest.contentItem)

            const receivePanel = findChild(controlUnderTest, "receivePanel")
            verify(!!receivePanel)
            waitForRendering(receivePanel)
            const amountToSendInput = findChild(receivePanel, "amountToSendInput")
            verify(!!amountToSendInput)
            const bottomItemText = findChild(receivePanel, "bottomItemText")
            verify(!!bottomItemText)
            const holdingSelector = findChild(receivePanel, "holdingSelector")
            verify(!!holdingSelector)
            const tokenSelectorContentItemText = findChild(receivePanel, "tokenSelectorContentItemText")
            verify(!!tokenSelectorContentItemText)
            const tokenSelectorIcon = findChild(receivePanel, "tokenSelectorIcon")
            verify(!!tokenSelectorIcon)
            const payTokenModel = receivePanel.tokenSelectorModel
            verify(!!payTokenModel)

            let expectedToken = SQUtils.ModelUtils.getByKey(payTokenModel, "key", sttGroupKey)
            // TODO: this should be come interactive under https://github.com/status-im/status-desktop/issues/15095
            verify(!amountToSendInput.interactive)
            verify(!amountToSendInput.cursorVisible)
            compare(amountToSendInput.text, valueToReceive.toLocaleString(Qt.locale(), 'f', -128))
            compare(amountToSendInput.placeholderText, LocaleUtils.numberToLocaleString(0))
            tryCompare(bottomItemText, "text", root.swapAdaptor.currencyStore.formatCurrencyAmount(valueToReceive * expectedToken.cryptoPrice, root.swapAdaptor.currencyStore.currentCurrency))
            compare(tokenSelectorContentItemText.text, expectedToken.symbol)
            const expectedIconSource = expectedToken.logoUri || Constants.tokenIcon(expectedToken.symbol)
            compare(tokenSelectorIcon.image.source, expectedIconSource)
            verify(tokenSelectorIcon.visible)
            compare(receivePanel.selectedHoldingId, expectedToken.key)
            compare(receivePanel.value, valueToReceive)
            compare(receivePanel.rawValue, SQUtils.AmountsArithmetic.fromNumber(valueToReceiveString, expectedToken.decimals).toString())
            verify(receivePanel.valueValid)

            closeAndVerfyModal()
        }

        function test_modal_max_button_click_with_no_preset_pay_value() {
            launchAndVerfyModal()

            let walletAccounts = getProcessedAccountsModel()

            root.swapFormData.selectedAccountAddress = walletAccounts.get(1).address
            formValuesChanged.clear()

            root.swapFormData.selectedNetworkChainId = root.swapAdaptor.filteredFlatNetworksModel.get(0).chainId
            root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(root.swapFormData.selectedNetworkChainId)
            root.swapFormData.selectedAccountAddress = walletAccounts.get(0).address
            root.swapFormData.fromGroupKey = ethGroupKey
            root.swapFormData.toGroupKey = sttGroupKey

            formValuesChanged.wait()

            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)
            const balanceLine = findChild(payPanel, "balanceLine")
            verify(!!balanceLine)
            const amountToSendInput = findChild(payPanel, "amountToSendInput")
            verify(!!amountToSendInput)
            const bottomItemText = findChild(payPanel, "bottomItemText")
            verify(!!bottomItemText)
            const payPanelAssetsModel = payPanel.tokenSelectorModel
            verify(!!payPanelAssetsModel)
            const amountSlider = findChild(controlUnderTest, "amountSlider")
            verify(!!amountSlider)

            waitForRendering(payPanel, 200)

            let expectedToken =  SQUtils.ModelUtils.getByKey(payPanelAssetsModel, "key", ethGroupKey)

            verify(balanceLine.visible)
            let maxPossibleValue = WalletUtils.calculateMaxSafeSendAmount(payPanel.maxCryptoBalance, expectedToken.symbol, root.swapFormData.selectedNetworkChainId)
            compare(payPanel.maxSafeCryptoValue, maxPossibleValue)
            tryCompare(amountSlider, "to", maxPossibleValue)
            verify(amountToSendInput.interactive)
            verify(amountToSendInput.cursorVisible)
            compare(amountToSendInput.text, "")
            compare(amountToSendInput.placeholderText, LocaleUtils.numberToLocaleString(0))
            compare(bottomItemText.text, root.swapAdaptor.currencyStore.formatCurrencyAmount(0, root.swapAdaptor.currencyStore.currentCurrency))

            payPanel.setAmount(payPanel.maxSafeCryptoValue)
            waitForItemPolished(payPanel)

            formValuesChanged.wait()

            verify(amountToSendInput.interactive)
            verify(amountToSendInput.cursorVisible)
            if (maxPossibleValue > 0)
                fuzzyCompare(parseFloat(amountToSendInput.delocalized), maxPossibleValue, 1e-6)
            else
                compare(amountToSendInput.text, "")
            tryCompare(bottomItemText, "text", root.swapAdaptor.currencyStore.formatCurrencyAmount(maxPossibleValue * expectedToken.cryptoPrice, root.swapAdaptor.currencyStore.currentCurrency))

            closeAndVerfyModal()
        }

        function test_modal_pay_input_switching_accounts() {

            let walletAccounts = getProcessedAccountsModel()

            // test with pay value being set and not set
            let payValuesToTestWith = ["", "0.2"]

            for (let index = 0; index < payValuesToTestWith.length; index++) {
                let valueToExchangeString = payValuesToTestWith[index]
                let valueToExchange = Number(valueToExchangeString)

                // Asset chosen but no pay value set state -------------------------------------------------------------------------------
                root.swapFormData.fromTokenAmount = valueToExchangeString
                root.swapFormData.selectedAccountAddress = walletAccounts.get(0).address
                root.swapFormData.selectedNetworkChainId = root.swapAdaptor.filteredFlatNetworksModel.get(0).chainId
                root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(root.swapFormData.selectedNetworkChainId)
                root.swapFormData.fromGroupKey = sttGroupKey

                // Launch popup
                launchAndVerfyModal()

                const payPanel = findChild(controlUnderTest, "payPanel")
                verify(!!payPanel)
                const balanceLine = findChild(payPanel, "balanceLine")
                verify(!!balanceLine)
                const amountToSendInput = findChild(payPanel, "amountToSendInput")
                verify(!!amountToSendInput)

                const errorTag = findChild(controlUnderTest, "errorTag")
                verify(!!errorTag)

                for (let i=0; i< walletAccounts.count; i++) {
                    root.swapFormData.selectedAccountAddress = walletAccounts.get(i).address

                    waitForRendering(payPanel)

                    const payTokenModel = payPanel.tokenSelectorModel
                    verify(!!payTokenModel)

                    let expectedToken = SQUtils.ModelUtils.getByKey(payTokenModel, "key", sttGroupKey)

                    // check states for the pay input selector
                    tryCompare(balanceLine, "visible", true)
                    let maxPossibleValue = WalletUtils.calculateMaxSafeSendAmount(expectedToken.currentBalance, expectedToken.symbol)
                    tryCompare(payPanel, "maxSafeCryptoValue", WalletUtils.calculateMaxSafeSendAmount(payPanel.maxCryptoBalance, expectedToken.symbol, root.swapFormData.selectedNetworkChainId))
                    compare(payPanel.selectedHoldingId, expectedToken.key)
                    tryCompare(payPanel, "valueValid", !!valueToExchangeString && valueToExchange <= maxPossibleValue)

                    tryCompare(payPanel, "value", valueToExchange)
                    compare(payPanel.rawValue, !!valueToExchangeString ? SQUtils.AmountsArithmetic.fromNumber(valueToExchangeString, expectedToken.decimals).toString(): "0")

                    // check if tag is visible in case amount entered to exchange is greater than max balance to send
                    let amountEnteredGreaterThanMaxBalance = valueToExchange > maxPossibleValue
                    let errortext = amountEnteredGreaterThanMaxBalance ? qsTr("Insufficient funds for swap"): qsTr("An error has occured, please try again")
                    compare(errorTag.visible, amountEnteredGreaterThanMaxBalance)
                    compare(errorTag.text, root.swapAdaptor.errorMessage)
                    compare(errorTag.buttonText, root.swapAdaptor.isTokenBalanceInsufficient ? qsTr("Add assets") : qsTr("Add ETH"))
                    compare(errorTag.buttonVisible, amountEnteredGreaterThanMaxBalance)
                }

                closeAndVerfyModal()
            }
        }

        function test_modal_exchange_button_enabled_state_data() {
            return [
                        {fromToken: "", fromTokenAmount: "", toToken: "", toTokenAmount: ""},
                        {fromToken: "", fromTokenAmount: "", toToken: sttGroupKey, toTokenAmount: ""},
                        {fromToken: ethGroupKey, fromTokenAmount: "", toToken: "", toTokenAmount: ""},
                        {fromToken: ethGroupKey, fromTokenAmount: "", toToken: sttGroupKey, toTokenAmount: ""},
                        {fromToken: ethGroupKey, fromTokenAmount: "100", toToken: sttGroupKey, toTokenAmount: ""},
                        {fromToken: ethGroupKey, fromTokenAmount: "", toToken: sttGroupKey, toTokenAmount: "50"},
                        {fromToken: ethGroupKey, fromTokenAmount: "100", toToken: sttGroupKey, toTokenAmount: "50"},
                        {fromToken: "", fromTokenAmount: "", toToken: "", toTokenAmount: "50"},
                        {fromToken: "", fromTokenAmount: "100", toToken: "", toTokenAmount: ""}
                    ]
        }

        function test_modal_exchange_button_enabled_state(data) {
            // Launch popup
            launchAndVerfyModal()
            const swapExchangeButton = findChild(controlUnderTest, "swapExchangeButton")
            verify(!!swapExchangeButton)

            root.swapFormData.fromGroupKey = data.fromToken
            root.swapFormData.fromTokenAmount = data.fromTokenAmount
            root.swapFormData.toGroupKey = data.toToken
            root.swapFormData.toTokenAmount = data.toTokenAmount

            tryCompare(swapExchangeButton, "enabled", !!data.fromToken || !!data.toToken)
        }

        function test_modal_exchange_button_default_state_data() {
            return [
                        {fromToken: "", fromTokenAmount: "", toToken: "", toTokenAmount: ""},
                        {fromToken: "", fromTokenAmount: "", toToken: sttGroupKey, toTokenAmount: ""},
                        {fromToken: ethGroupKey, fromTokenAmount: "", toToken: "", toTokenAmount: ""},
                        {fromToken: ethGroupKey, fromTokenAmount: "", toToken: sttGroupKey, toTokenAmount: ""},
                        {fromToken: ethGroupKey, fromTokenAmount: "100", toToken: sttGroupKey, toTokenAmount: ""},
                        {fromToken: ethGroupKey, fromTokenAmount: "", toToken: sttGroupKey, toTokenAmount: "50"},
                        {fromToken: ethGroupKey, fromTokenAmount: "100", toToken: sttGroupKey, toTokenAmount: "50"},
                        {fromToken: "", fromTokenAmount: "", toToken: "", toTokenAmount: "50"},
                        {fromToken: "", fromTokenAmount: "100", toToken: "", toTokenAmount: ""}
                    ]
        }

        function test_modal_exchange_button_default_state(data) {
            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)
            const receivePanel = findChild(controlUnderTest, "receivePanel")
            verify(!!receivePanel)
            const swapExchangeButton = findChild(controlUnderTest, "swapExchangeButton")
            verify(!!swapExchangeButton)

            const payAmountToSendInput = findChild(payPanel, "amountToSendInput")
            verify(!!payAmountToSendInput)
            const payBottomItemText = findChild(payPanel, "bottomItemText")
            verify(!!payBottomItemText)
            const balanceLine = findChild(payPanel, "balanceLine")
            verify(!!balanceLine)

            const receiveAmountToSendInput = findChild(receivePanel, "amountToSendInput")
            verify(!!receiveAmountToSendInput)
            const receiveBottomItemText = findChild(receivePanel, "bottomItemText")
            verify(!!receiveBottomItemText)

            let walletAccounts = getProcessedAccountsModel()

            root.swapAdaptor.reset()

            // set network and address by default same
            root.swapFormData.selectedNetworkChainId = root.swapAdaptor.filteredFlatNetworksModel.get(0).chainId
            root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(root.swapFormData.selectedNetworkChainId)
            root.swapFormData.selectedAccountAddress = walletAccounts.get(0).address
            root.swapFormData.fromGroupKey = data.fromToken
            root.swapFormData.fromTokenAmount = data.fromTokenAmount
            root.swapFormData.toGroupKey = data.toToken
            root.swapFormData.toTokenAmount = data.toTokenAmount

            // Launch popup
            launchAndVerfyModal()
            waitForRendering(payPanel)
            waitForRendering(receivePanel)
            waitForRendering(payAmountToSendInput)

            let expectedFromTokenKey = !!data.fromToken ? data.fromToken : root.swapFormData.defaultFromGroupKey
            let expectedToTokenKey = !!data.toToken ? data.toToken : root.swapFormData.defaultToGroupKey
            const payTokenModel = payPanel.tokenSelectorModel
            verify(!!payTokenModel)
            const receiveTokenModel = receivePanel.tokenSelectorModel
            verify(!!receiveTokenModel)
            const expectedFromToken = !!expectedFromTokenKey ? SQUtils.ModelUtils.getByKey(payTokenModel, "key", expectedFromTokenKey) : null
            const expectedToToken = !!expectedToTokenKey ? SQUtils.ModelUtils.getByKey(receiveTokenModel, "key", expectedToTokenKey) : null
            let expectedFromTokenIcon = !!expectedFromToken ? expectedFromToken.logoUri : ""
            let expectedToTokenIcon = !!expectedToToken ? expectedToToken.logoUri : ""

            let paytokenSelectorContentItemText = findChild(payPanel, "tokenSelectorContentItemText")
            verify(!!paytokenSelectorContentItemText)
            let paytokenSelectorIcon = findChild(payPanel, "tokenSelectorIcon")
            verify(!!paytokenSelectorIcon === !!expectedFromTokenKey)
            let receivetokenSelectorContentItemText = findChild(receivePanel, "tokenSelectorContentItemText")
            verify(!!receivetokenSelectorContentItemText)
            let receivetokenSelectorIcon = findChild(receivePanel, "tokenSelectorIcon")
            verify(!!receivetokenSelectorIcon === !!expectedToTokenKey)

            // verify pay values
            compare(payPanel.groupKey, expectedFromTokenKey)
            compare(payPanel.tokenAmount, data.fromTokenAmount)
            verify(payAmountToSendInput.cursorVisible)
            compare(paytokenSelectorContentItemText.text, expectedFromToken ? expectedFromToken.symbol : qsTr("Select asset"))
            compare(!!payPanel.groupKey , !!paytokenSelectorIcon)
            if(!!paytokenSelectorIcon) {
                compare(paytokenSelectorIcon.image.source, expectedFromTokenIcon)
            }
            verify(!!expectedFromTokenKey ? balanceLine.visible: !balanceLine.visible)

            // verify receive values
            compare(receivePanel.groupKey, expectedToTokenKey)
            compare(receivePanel.tokenAmount, data.toTokenAmount)
            verify(!receiveAmountToSendInput.cursorVisible)
            compare(receivetokenSelectorContentItemText.text, expectedToToken ? expectedToToken.symbol : qsTr("Select asset"))
            if(!!receivetokenSelectorIcon) {
                compare(receivetokenSelectorIcon.image.source, expectedToTokenIcon)
            }

            // click exchange button
            swapExchangeButton.clicked()
            waitForRendering(payPanel)
            waitForRendering(receivePanel)

            // verify form values
            compare(root.swapFormData.fromGroupKey, expectedToTokenKey)
            compare(root.swapFormData.fromTokenAmount, data.toTokenAmount)
            compare(root.swapFormData.toGroupKey, expectedFromTokenKey)
            compare(root.swapFormData.toTokenAmount, data.fromTokenAmount)

            paytokenSelectorContentItemText = findChild(payPanel, "tokenSelectorContentItemText")
            verify(!!paytokenSelectorContentItemText)
            paytokenSelectorIcon = findChild(payPanel, "tokenSelectorIcon")
            compare(!!root.swapFormData.fromGroupKey , !!paytokenSelectorIcon)
            receivetokenSelectorContentItemText = findChild(receivePanel, "tokenSelectorContentItemText")
            verify(!!receivetokenSelectorContentItemText)
            receivetokenSelectorIcon = findChild(receivePanel, "tokenSelectorIcon")
            compare(!!root.swapFormData.toGroupKey, !!receivetokenSelectorIcon)

            // verify pay values
            compare(payPanel.groupKey, expectedToTokenKey)
            compare(payPanel.tokenAmount, data.toTokenAmount)
            verify(payAmountToSendInput.cursorVisible)
            const swappedFromToken = !!root.swapFormData.fromGroupKey ? SQUtils.ModelUtils.getByKey(payTokenModel, "key", root.swapFormData.fromGroupKey) : null
            const swappedToToken = !!root.swapFormData.toGroupKey ? SQUtils.ModelUtils.getByKey(receiveTokenModel, "key", root.swapFormData.toGroupKey) : null
            compare(paytokenSelectorContentItemText.text, swappedFromToken ? swappedFromToken.symbol : qsTr("Select asset"))
            if(!!paytokenSelectorIcon) {
                compare(paytokenSelectorIcon.image.source, swappedFromToken ? swappedFromToken.logoUri : "")
            }
            verify(!!payPanel.groupKey ? balanceLine.visible: !balanceLine.visible)

            // verify receive values
            compare(receivePanel.groupKey, expectedFromTokenKey)
            compare(receivePanel.tokenAmount, data.fromTokenAmount)
            verify(!receiveAmountToSendInput.cursorVisible)
            compare(receivetokenSelectorContentItemText.text, swappedToToken ? swappedToToken.symbol : qsTr("Select asset"))
            if(!!receivetokenSelectorIcon) {
                compare(receivetokenSelectorIcon.image.source, swappedToToken ? swappedToToken.logoUri : "")
            }

            closeAndVerfyModal()
        }

        function test_approval_flow_button_states() {
            root.swapAdaptor.reset()

            // Launch popup
            launchAndVerfyModal()

            const strategyFees = findChild(controlUnderTest, "strategyFees")
            verify(!!strategyFees)
            const signButton = findChild(controlUnderTest, "signButton")
            verify(!!signButton)
            const errorTag = findChild(controlUnderTest, "errorTag")
            verify(!!errorTag)
            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)
            const receivePanel = findChild(controlUnderTest, "receivePanel")
            verify(!!receivePanel)

            verify(!signButton.interactive)
            verify(!errorTag.visible)

            // set input values in the form correctly
            root.swapFormData.fromGroupKey = sttGroupKey
            formValuesChanged.wait()
            root.swapFormData.toGroupKey = root.swapAdaptor.walletAssetsStore.walletTokensStore.tokenGroupsModel.get(1).key
            root.swapFormData.fromTokenAmount = "0.001"
            formValuesChanged.wait()
            root.swapFormData.selectedNetworkChainId = 11155420
            root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(root.swapFormData.selectedNetworkChainId)
            formValuesChanged.wait()
            root.swapFormData.selectedAccountAddress = "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            formValuesChanged.wait()

            // wait for fetchSuggestedRoutes function to be called
            fetchSuggestedRoutesCalled.wait()

            // verify loading state was set and no errors currently
            verifyLoadingAndNoErrorsState(payPanel, receivePanel)

            // emit event with route that needs no approval
            let txRoutes = root.dummySwapTransactionRoutes.txHasRoutesApprovalNeeded
            txRoutes.uuid = root.swapAdaptor.uuid
            root.swapStore.suggestedRoutesReady(txRoutes, "", "")

            // calculation needed for total fees
            let gasTimeEstimate = txRoutes.gasTimeEstimate
            let totalTokenFeesInFiat = gasTimeEstimate.totalTokenFees * root.swapAdaptor.fromToken.marketDetails.currencyPrice.amount
            let totalFees = root.swapAdaptor.currencyStore.getFiatValue(gasTimeEstimate.totalFeesInNativeCrypto, Constants.ethToken) + totalTokenFeesInFiat
            let bestPath = SQUtils.ModelUtils.get(txRoutes.suggestedRoutes, 0, "route")

            // verify loading state removed and data is displayed as expected on the Modal
            verify(root.swapAdaptor.validSwapProposalReceived)
            verify(!root.swapAdaptor.swapProposalLoading)
            compare(root.swapAdaptor.swapOutputData.fromTokenAmount, "")
            compare(root.swapAdaptor.swapOutputData.toTokenAmount, SQUtils.AmountsArithmetic.div(
                        SQUtils.AmountsArithmetic.fromString(txRoutes.amountToReceive),
                        SQUtils.AmountsArithmetic.fromNumber(1, root.swapAdaptor.toToken.decimals)).toString())
            compare(root.swapAdaptor.swapOutputData.totalFees, totalFees)
            compare(root.swapAdaptor.swapOutputData.hasError, false)
            compare(root.swapAdaptor.swapOutputData.estimatedTime, bestPath.estimatedTime)
            compare(root.swapAdaptor.swapOutputData.txProviderName, bestPath.bridgeName)
            compare(root.swapAdaptor.swapOutputData.approvalNeeded, true)
            compare(root.swapAdaptor.swapOutputData.approvalGasFees, bestPath.approvalGasFees.toString())
            compare(root.swapAdaptor.swapOutputData.approvalAmountRequired, bestPath.approvalAmountRequired)
            compare(root.swapAdaptor.swapOutputData.approvalContractAddress, bestPath.approvalContractAddress)

            verify(!errorTag.visible, "error tag visible with text: " + errorTag.text)
            verify(signButton.enabled)
            verify(!signButton.loadingWithText)
            compare(signButton.text, qsTr("Approve %1").arg(root.swapAdaptor.fromToken.symbol))
            // TODO: note that there is a loss of precision as the approvalGasFees is currently passes as float from the backend and not string.
            tryCompare(strategyFees, "text", root.swapAdaptor.currencyStore.formatCurrencyAmount(
                        root.swapAdaptor.swapOutputData.txFeesInFiat,
                        root.swapAdaptor.currencyStore.currentCurrency))

            // simulate user click on approve button and approval failed
            root.swapStore.transactionSent(root.swapAdaptor.uuid, root.swapFormData.selectedNetworkChainId, true, "0x877ffe47fc29340312611d4e833ab189fe4f4152b01cc9a05bb4125b81b2a89a", "")

            verify(root.swapAdaptor.approvalPending)
            verify(!root.swapAdaptor.approvalSuccessful)
            verify(!errorTag.visible)
            verify(!signButton.interactive)
            verify(signButton.loadingWithText)
            compare(signButton.text, qsTr("Approving %1").arg(root.swapAdaptor.fromToken.symbol))
            // TODO: note that there is a loss of precision as the approvalGasFees is currently passes as float from the backend and not string.
            tryCompare(strategyFees, "text", root.swapAdaptor.currencyStore.formatCurrencyAmount(
                        root.swapAdaptor.swapOutputData.txFeesInFiat,
                        root.swapAdaptor.currencyStore.currentCurrency))

            // simulate approval tx was unsuccessful
            root.swapStore.transactionSendingComplete("0x877ffe47fc29340312611d4e833ab189fe4f4152b01cc9a05bb4125b81b2a89a", "Failed")

            verify(!root.swapAdaptor.approvalPending)
            verify(!root.swapAdaptor.approvalSuccessful)
            verify(!errorTag.visible)
            verify(signButton.enabled)
            verify(!signButton.loadingWithText)
            compare(signButton.text, qsTr("Approve %1").arg(root.swapAdaptor.fromToken.symbol))
            // TODO: note that there is a loss of precision as the approvalGasFees is currently passes as float from the backend and not string.
            tryCompare(strategyFees, "text", root.swapAdaptor.currencyStore.formatCurrencyAmount(
                        root.swapAdaptor.swapOutputData.txFeesInFiat,
                        root.swapAdaptor.currencyStore.currentCurrency))

            // simulate user click on approve button and successful approval tx made
            signButton.clicked()
            root.swapStore.transactionSent(root.swapAdaptor.uuid, root.swapFormData.selectedNetworkChainId, true, "0x877ffe47fc29340312611d4e833ab189fe4f4152b01cc9a05bb4125b81b2a89a", "")

            verify(root.swapAdaptor.approvalPending)
            verify(!root.swapAdaptor.approvalSuccessful)
            verify(!errorTag.visible)
            verify(!signButton.interactive)
            verify(signButton.loadingWithText)
            compare(signButton.text, qsTr("Approving %1").arg(root.swapAdaptor.fromToken.symbol))
            // TODO: note that there is a loss of precision as the approvalGasFees is currently passes as float from the backend and not string.
            tryCompare(strategyFees, "text", root.swapAdaptor.currencyStore.formatCurrencyAmount(
                        root.swapAdaptor.swapOutputData.txFeesInFiat,
                        root.swapAdaptor.currencyStore.currentCurrency))

            root.swapStore.transactionSendingComplete("0x877ffe47fc29340312611d4e833ab189fe4f4152b01cc9a05bb4125b81b2a89a", "Success")

            // simulate approval tx was successful
            signButton.clicked()

            root.swapStore.transactionSendingComplete("0x877ffe47fc29340312611d4e833ab189fe4f4152b01cc9a05bb4125b81b2a89a", "Success")

            verify(!root.swapAdaptor.approvalPending)
            verify(root.swapAdaptor.approvalSuccessful)
            verify(!errorTag.visible)
            verify(signButton.interactive)
            verify(!signButton.loadingWithText)
            compare(signButton.text, qsTr("Confirm swap"))
            tryCompare(strategyFees, "text", root.swapAdaptor.currencyStore.formatCurrencyAmount(
                        root.swapAdaptor.swapOutputData.txFeesInFiat,
                        root.swapAdaptor.currencyStore.currentCurrency))

            let txHasRouteNoApproval = root.dummySwapTransactionRoutes.txHasRouteNoApproval
            txHasRouteNoApproval.uuid = root.swapAdaptor.uuid
            root.swapStore.suggestedRoutesReady(txHasRouteNoApproval, "", "")

            verify(!root.swapAdaptor.approvalPending)
            verify(root.swapAdaptor.approvalSuccessful)
            verify(!errorTag.visible)
            verify(signButton.enabled)
            verify(!signButton.loadingWithText)
            compare(signButton.text, qsTr("Confirm swap"))
            tryCompare(strategyFees, "text", root.swapAdaptor.currencyStore.formatCurrencyAmount(
                        root.swapAdaptor.swapOutputData.txFeesInFiat,
                        root.swapAdaptor.currencyStore.currentCurrency))
            closeAndVerfyModal()
        }

        function test_modal_switching_networks_payPanel_data() {
            return [
                        {key: ethGroupKey},
                        {key: "aave"}
                    ]
        }

        function test_modal_switching_networks_payPanel(data) {
            // try setting value before popup is launched and check values
            let valueToExchange = 1
            let valueToExchangeString = valueToExchange.toString()
            root.swapFormData.selectedAccountAddress = "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            root.swapFormData.fromGroupKey = data.key
            root.swapFormData.fromTokenAmount = valueToExchangeString

            // Launch popup
            launchAndVerfyModal()

            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)
            const networkBadgeText = findChild(payPanel, "networkBadgeText")
            verify(!!networkBadgeText)
            const payAssetsModel = payPanel.tokenSelectorModel
            verify(!!payAssetsModel)

            const activeNetworks = root.swapAdaptor.networksStore.activeNetworks

            for (let i=0; i<activeNetworks.count; i++) {
                const chainId = activeNetworks.get(i).chainId

                payPanel.listChainFilter = chainId
                root.swapFormData.selectedNetworkChainId = chainId
                root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(chainId)

                waitForRendering(payPanel)

                tryCompare(networkBadgeText, "text", activeNetworks.get(i).chainName)

                let existsOnChain = !!SQUtils.ModelUtils.getByKey(root.swapAdaptor.walletAssetsStore.walletTokensStore.tokenGroupsForChainModel, "key", root.swapFormData.fromGroupKey)

                tryVerify(() => (!!SQUtils.ModelUtils.getByKey(payAssetsModel, "key", root.swapFormData.fromGroupKey)) === existsOnChain,
                          1000, "token presence in chain-filtered list mismatch for chain " + chainId)
            }

            closeAndVerfyModal()
        }

        function test_modal_switching_networks_receivePanel_data() {
                return [
                            {key: "aave"},
                            {key: sttGroupKey}
                        ]
        }

        function test_modal_switching_networks_receivePanel(data) {
            // try setting value before popup is launched and check values
            let valueToExchange = 1
            let valueToExchangeString = valueToExchange.toString()
            root.swapFormData.selectedAccountAddress = "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            root.swapFormData.fromGroupKey = ethGroupKey
            root.swapFormData.fromTokenAmount = valueToExchangeString
            root.swapFormData.toGroupKey = data.key

            // Launch popup
            launchAndVerfyModal()

            const receivePanel = findChild(controlUnderTest, "receivePanel")
            verify(!!receivePanel)
            const receiveAssetsModel = receivePanel.tokenSelectorModel
            verify(!!receiveAssetsModel)

            const activeNetworks = root.swapAdaptor.networksStore.activeNetworks

            for (let i=0; i<activeNetworks.count; i++) {
                const chainId = activeNetworks.get(i).chainId

                receivePanel.listChainFilter = chainId
                root.swapFormData.toNetworkChainId = chainId
                root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(chainId)

                waitForRendering(receivePanel)

                let existsOnChain = !!SQUtils.ModelUtils.getByKey(root.swapAdaptor.walletAssetsStore.walletTokensStore.tokenGroupsForChainToModel, "key", root.swapFormData.toGroupKey)

                tryVerify(() => (!!SQUtils.ModelUtils.getByKey(receiveAssetsModel, "key", root.swapFormData.toGroupKey)) === existsOnChain,
                          1000, "token presence in chain-filtered list mismatch for chain " + chainId)
            }

            closeAndVerfyModal()
        }

        function test_auto_refresh() {
            // Asset chosen but no pay value set state -------------------------------------------------------------------------------
            root.swapFormData.fromTokenAmount = "0.0001"
            root.swapFormData.selectedAccountAddress = "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            root.swapFormData.selectedNetworkChainId = 11155111
            root.swapFormData.fromGroupKey = ethGroupKey
            // for testing making it 1.2 seconds so as to not make tests running too long
            root.swapFormData.autoRefreshTime = 1200

            // Launch popup
            launchAndVerfyModal()

            // check if fetchSuggestedRoutes called
            fetchSuggestedRoutesCalled.wait()

            // emit routes ready
            let txHasRouteNoApproval = root.dummySwapTransactionRoutes.txHasRouteNoApproval
            txHasRouteNoApproval.uuid = root.swapAdaptor.uuid
            root.swapStore.suggestedRoutesReady(txHasRouteNoApproval, "", "")
        }

        function test_deleteing_input_characters_data() {
            return [
                        {input: "0.001", locale: Qt.locale("en_US")},
                        {input: "1.00015", locale: Qt.locale("en_US")},
                        {input: "0.001", locale: Qt.locale("pl_PL")},
                        {input: "1.90015", locale: Qt.locale("pl_PL")},
                        {input: "100.000000000000151001", locale: Qt.locale("en_US")},
                        {input: "1.020000000000015101", locale: Qt.locale("en_US")}
                    ]
        }

        function test_deleteing_input_characters(data) {
            root.swapFormData.selectedAccountAddress = "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            root.swapFormData.selectedNetworkChainId = 11155111
            root.swapFormData.fromGroupKey = ethGroupKey
            root.swapFormData.fromTokenAmount = data.input

            const amountToSendInput = findChild(controlUnderTest, "amountToSendInput")
            verify(!!amountToSendInput)
            const amountToSend_textField = findChild(controlUnderTest, "amountToSend_textField")
            verify(!!amountToSend_textField)

            amountToSendInput.locale = data.locale

            // Launch popup
            launchAndVerfyModal()
            mouseClick(amountToSendInput)
            waitForRendering(amountToSendInput)
            amountToSend_textField.cursorPosition = amountToSendInput.text.length

            let amountToTestInLocale = data.input.replace('.', amountToSendInput.locale.decimalPoint)
            for(let i =0; i< data.input.length; i++) {
                keyClick(Qt.Key_Backspace)
                let expectedAmount = amountToTestInLocale.substring(0, data.input.length - (i+1))
                tryCompare(amountToSendInput, "text", expectedAmount)
            }
        }

        function test_no_auto_refresh_when_proposalLoading_or_approvalPending() {
            fetchSuggestedRoutesCalled.clear()
            root.swapFormData.fromTokenAmount = "0.0001"
            root.swapFormData.selectedAccountAddress = "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            root.swapFormData.selectedNetworkChainId = 11155111
            root.swapFormData.fromGroupKey = ethGroupKey
            // for testing making it 1.2 seconds so as to not make tests running too long
            root.swapFormData.autoRefreshTime = 1200

            // Launch popup
//            launchAndVerfyModal()

//            // check if fetchSuggestedRoutes called
//            tryCompare(fetchSuggestedRoutesCalled, "count", 1)

            // no new calls to fetch new proposal should be made as the proposal is still loading
//            wait(root.swapFormData.autoRefreshTime*2)
//            compare(fetchSuggestedRoutesCalled.count, 1)

//            // emit routes ready
//            let txHasRouteApproval = root.dummySwapTransactionRoutes.txHasRoutesApprovalNeeded
//            txHasRouteApproval.uuid = root.swapAdaptor.uuid
//            root.swapStore.suggestedRoutesReady(txHasRouteApproval, "", "")

//            // now refresh can occur as no propsal or signing is pending
//            tryCompare(fetchSuggestedRoutesCalled, "count", 2)

//            // emit routes ready
//            txHasRouteApproval.uuid = root.swapAdaptor.uuid
//            root.swapStore.suggestedRoutesReady(txHasRouteApproval, "", "")

//            verify(root.swapAdaptor.swapOutputData.approvalNeeded)
//            verify(!root.swapAdaptor.approvalPending)

//            // sign approval and check that auto refresh doesnt occur
//            root.swapAdaptor.sendApproveTx()

//            // no new calls to fetch new proposal should be made as the approval is pending
//            verify(root.swapAdaptor.swapOutputData.approvalNeeded)
//            verify(root.swapAdaptor.approvalPending)
//            wait(root.swapFormData.autoRefreshTime*2)
//            compare(fetchSuggestedRoutesCalled.count, 2)
        }

        function test_uuid_change() {
            root.swapFormData.fromTokenAmount = "0.0001"
            root.swapFormData.selectedAccountAddress = "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            root.swapFormData.selectedNetworkChainId = 11155111
            root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(root.swapFormData.selectedNetworkChainId)
            root.swapFormData.fromGroupKey = ethGroupKey
            root.swapFormData.toGroupKey = sttGroupKey

            // Launch popup
            launchAndVerfyModal()

            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)

            const receivePanel = findChild(controlUnderTest, "receivePanel")
            verify(!!receivePanel)

            waitForItemPolished(controlUnderTest.contentItem)

            // check if fetchSuggestedRoutes called
            fetchSuggestedRoutesCalled.wait()

            // emit routes ready
            let txHasRouteNoApproval = root.dummySwapTransactionRoutes.txHasRouteNoApproval
            txHasRouteNoApproval.uuid = root.swapAdaptor.uuid
            root.swapStore.suggestedRoutesReady(txHasRouteNoApproval, "", "")

            let lastUuid = root.swapAdaptor.uuid

            // edit some params to retry swap
            root.swapFormData.fromTokenAmount = "0.00011"
            waitForRendering(receivePanel)
            formValuesChanged.wait()
            // verify loading state was set and no errors currently
            verifyLoadingAndNoErrorsState(payPanel, receivePanel)

            // uuid changed
            verify(root.swapAdaptor.uuid !== lastUuid)

            // emit event with route that needs no approval for previous uuid
            txHasRouteNoApproval.uuid = lastUuid
            root.swapStore.suggestedRoutesReady(txHasRouteNoApproval, "", "")

            // route with old uuid should have been ignored
            verifyLoadingAndNoErrorsState(payPanel, receivePanel)

            // emit routes ready
            txHasRouteNoApproval.uuid = root.swapAdaptor.uuid
            root.swapStore.suggestedRoutesReady(txHasRouteNoApproval, "", "")

            // verify loading state removed and data is displayed as expected on the Modal
            verify(root.swapAdaptor.validSwapProposalReceived)
            verify(!root.swapAdaptor.swapProposalLoading)

            closeAndVerfyModal()
        }

        function test_exchange_rate() {
            root.swapAdaptor.walletAssetsStore.walletTokensStore.buildGroupsForChain(11155111)

            root.swapFormData.fromTokenAmount = "1"
            root.swapFormData.selectedAccountAddress = "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            root.swapFormData.selectedNetworkChainId = 11155111
            root.swapFormData.fromGroupKey = ethGroupKey
            root.swapFormData.toGroupKey = ""

            launchAndVerfyModal()

            const cs = root.swapAdaptor.currencyStore

            const quoteText = findChild(controlUnderTest, "swapQuoteText")
            verify(!!quoteText)

            const invertQuoteButton = findChild(controlUnderTest, "invertQuoteButton")
            verify(!!invertQuoteButton)

            compare(quoteText.text, "")
            verify(!invertQuoteButton.visible)

            fetchSuggestedRoutesCalled.clear()
            root.swapFormData.toGroupKey = sttGroupKey

            tryCompare(fetchSuggestedRoutesCalled, "count", 1)
            tryVerify(() => quoteText.loading)
            verify(!invertQuoteButton.visible)

            // emit routes ready
            let txHasRouteNoApproval = root.dummySwapTransactionRoutes.txHasRouteNoApproval
            txHasRouteNoApproval.uuid = root.swapAdaptor.uuid
            txHasRouteNoApproval.amountToReceive = "1000000000000000000" // "1" in STT
            root.swapStore.suggestedRoutesReady(txHasRouteNoApproval, "", "")

            tryVerify(() => !quoteText.loading)
            tryCompare(quoteText, "text", "1 ETH ≈ %1".arg(cs.formatCurrencyAmount(1, "STT")))
            verify(invertQuoteButton.visible)

            fetchSuggestedRoutesCalled.clear()
            root.swapFormData.fromTokenAmount = "2"

            tryCompare(fetchSuggestedRoutesCalled, "count", 1)
            tryVerify(() => quoteText.loading)
            verify(!invertQuoteButton.visible)

            // emit routes ready
            txHasRouteNoApproval = root.dummySwapTransactionRoutes.txHasRouteNoApproval
            txHasRouteNoApproval.uuid = root.swapAdaptor.uuid
            txHasRouteNoApproval.amountToReceive = "4000000000000000000" // "4" in STT
            root.swapStore.suggestedRoutesReady(txHasRouteNoApproval, "", "")

            tryCompare(quoteText, "text", "1 ETH ≈ %1".arg(cs.formatCurrencyAmount(2, "STT")))
            verify(invertQuoteButton.visible)

            mouseClick(invertQuoteButton)
            tryCompare(quoteText, "text", "1 STT ≈ %1".arg(cs.formatCurrencyAmount(0.5, "ETH")))
        }

        // The handler destroys the modal and then resets the form, and the reset
        // clears the source chain before the destination one — a transient bridge
        // state. Building the destination picker for it (an expensive terminal
        // model) only to throw it away is pure waste on every plain-swap close.
        function test_noBridgePickerIsBuiltWhileClosing() {
            const store = root.swapAdaptor.walletAssetsStore.walletTokensStore

            launchAndVerfyModal()
            compare(root.swapFormData.selectedNetworkChainId,
                    root.swapFormData.toNetworkChainId, "plain same-chain swap")

            store.createdKinds = []

            controlUnderTest.close()
            verify(!controlUnderTest.opened)
            // same order as SwapModalHandler.onClosed
            root.swapFormData.resetFormData()

            compare(store.createdKinds.indexOf(3), -1,
                    "no destination picker built during teardown, got kinds: "
                    + JSON.stringify(store.createdKinds))
        }

        function test_payChainFilterDrivesTheCatalog() {
            const store = root.swapAdaptor.walletAssetsStore.walletTokensStore

            launchAndVerfyModal()

            const payPanel = findChild(controlUnderTest, "payPanel")
            verify(!!payPanel)
            const payChainId = root.swapFormData.selectedNetworkChainId
            const chainFilter = findChild(payPanel, "chainFilter")
            verify(!!chainFilter)

            const otherChainId = payChainId === 10 ? 1 : 10
            store.builtChainIds = []
            chainFilter.chainSelected(otherChainId)

            compare(store.builtChainIds, [otherChainId], "catalog scoped to the filter")
            compare(root.swapFormData.selectedNetworkChainId, payChainId,
                    "and the swap stays on its own chain")

            store.builtChainIds = []
            chainFilter.chainSelected(-1)

            compare(store.builtChainIds, [payChainId], "\"All\" restores this side's catalog")

            closeAndVerfyModal()
        }

        // A destination picker built lazily (the user switches the receive chain
        // after the modal is open) must be seeded like the ones createPickers
        // builds, otherwise it starts on whatever the producer's last search was.
        function test_lazyBridgePickerIsSeeded() {
            const store = root.swapAdaptor.walletAssetsStore.walletTokensStore

            launchAndVerfyModal()

            const receivePanel = findChild(controlUnderTest, "receivePanel")
            verify(!!receivePanel)

            store.createdKinds = []
            root.swapFormData.toNetworkChainId = 10 // != source chain => bridge

            compare(store.createdKinds.indexOf(3), 0, "destination picker built")
            const bridgeModel = receivePanel.tokenSelectorModel
            verify(!!bridgeModel, "the receive panel is switched to it")
            compare(bridgeModel.searchCallCount, 1, "and it is seeded")

            closeAndVerfyModal()
        }
    }
}
