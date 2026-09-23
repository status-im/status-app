import nimqml

import app_service/common/wallet_constants

QtObject:
  type PathItem* = ref object of QObject
    processorName: string
    fromChain: int
    fromChainEIP1559Compliant: bool
    fromChainNoBaseFee: bool
    fromChainNoPriorityFee: bool
    toChain: int
    fromToken: string
    toToken: string
    amountIn: string
    amountInLocked: bool
    amountOut: string
    suggestedNonEIP1559GasPrice: string
    suggestedNonEIP1559EstimatedTime: int
    suggestedMaxFeesPerGasLowLevel: string
    suggestedPriorityFeePerGasLowLevel: string
    suggestedEstimatedTimeLowLevel: int
    suggestedMaxFeesPerGasMediumLevel: string
    suggestedPriorityFeePerGasMediumLevel: string
    suggestedEstimatedTimeMediumLevel: int
    suggestedMaxFeesPerGasHighLevel: string
    suggestedPriorityFeePerGasHighLevel: string
    suggestedEstimatedTimeHighLevel: int
    suggestedMinPriorityFee: string
    suggestedMaxPriorityFee: string
    currentBaseFee: string
    suggestedTxNonce: string
    suggestedTxGasAmount: string
    suggestedApprovalTxNonce: string
    suggestedApprovalGasAmount: string
    txNonce: string
    txGasPrice: string
    txGasFeeMode: int
    txMaxFeesPerGas: string
    txBaseFee: string
    txPriorityFee: string
    txGasAmount: string
    txBonderFees: string
    txTokenFees: string
    txEstimatedTime: int
    txFee: string
    txL1Fee: string
    txTotalFee: string
    approvalRequired: bool
    approvalAmountRequired : string
    approvalContractAddress: string
    approvalTxNonce: string
    approvalGasPrice: string
    approvalGasFeeMode: int
    approvalMaxFeesPerGas: string
    approvalBaseFee: string
    approvalPriorityFee: string
    approvalGasAmount: string
    approvalEstimatedTime: int
    approvalFee: string
    approvalL1Fee: string

  proc setup*(self: PathItem,
    processorName: string,
    fromChain: int,
    fromChainEIP1559Compliant: bool,
    fromChainNoBaseFee: bool,
    fromChainNoPriorityFee: bool,
    toChain: int,
    fromToken: string,
    toToken: string,
    amountIn: string,
    amountInLocked: bool,
    amountOut: string,
    suggestedNonEIP1559GasPrice: string,
    suggestedNonEIP1559EstimatedTime: int,
    suggestedMaxFeesPerGasLowLevel: string,
    suggestedPriorityFeePerGasLowLevel: string,
    suggestedEstimatedTimeLowLevel: int,
    suggestedMaxFeesPerGasMediumLevel: string,
    suggestedPriorityFeePerGasMediumLevel: string,
    suggestedEstimatedTimeMediumLevel: int,
    suggestedMaxFeesPerGasHighLevel: string,
    suggestedPriorityFeePerGasHighLevel: string,
    suggestedEstimatedTimeHighLevel: int,
    suggestedMinPriorityFee: string,
    suggestedMaxPriorityFee: string,
    currentBaseFee: string,
    suggestedTxNonce: string,
    suggestedTxGasAmount: string,
    suggestedApprovalTxNonce: string,
    suggestedApprovalGasAmount: string,
    txNonce: string,
    txGasPrice: string,
    txGasFeeMode: int,
    txMaxFeesPerGas: string,
    txBaseFee: string,
    txPriorityFee: string,
    txGasAmount: string,
    txBonderFees: string,
    txTokenFees: string,
    txEstimatedTime: int,
    txFee: string,
    txL1Fee: string,
    txTotalFee: string,
    approvalRequired: bool,
    approvalAmountRequired: string,
    approvalContractAddress: string,
    approvalTxNonce: string,
    approvalGasPrice: string,
    approvalGasFeeMode: int,
    approvalMaxFeesPerGas: string,
    approvalBaseFee: string,
    approvalPriorityFee: string,
    approvalGasAmount: string,
    approvalEstimatedTime: int,
    approvalFee: string,
    approvalL1Fee: string
  )
  proc delete*(self: PathItem)
  proc newPathItem*(
    processorName: string,
    fromChain: int,
    fromChainEIP1559Compliant: bool,
    fromChainNoBaseFee: bool,
    fromChainNoPriorityFee: bool,
    toChain: int,
    fromToken: string,
    toToken: string,
    amountIn: string,
    amountInLocked: bool,
    amountOut: string,
    suggestedNonEIP1559GasPrice: string,
    suggestedNonEIP1559EstimatedTime: int,
    suggestedMaxFeesPerGasLowLevel: string,
    suggestedPriorityFeePerGasLowLevel: string,
    suggestedEstimatedTimeLowLevel: int,
    suggestedMaxFeesPerGasMediumLevel: string,
    suggestedPriorityFeePerGasMediumLevel: string,
    suggestedEstimatedTimeMediumLevel: int,
    suggestedMaxFeesPerGasHighLevel: string,
    suggestedPriorityFeePerGasHighLevel: string,
    suggestedEstimatedTimeHighLevel: int,
    suggestedMinPriorityFee: string,
    suggestedMaxPriorityFee: string,
    currentBaseFee: string,
    suggestedTxNonce: string,
    suggestedTxGasAmount: string,
    suggestedApprovalTxNonce: string,
    suggestedApprovalGasAmount: string,
    txNonce: string,
    txGasPrice: string,
    txGasFeeMode: int,
    txMaxFeesPerGas: string,
    txBaseFee: string,
    txPriorityFee: string,
    txGasAmount: string,
    txBonderFees: string,
    txTokenFees: string,
    txEstimatedTime: int,
    txFee: string,
    txL1Fee: string,
    txTotalFee: string,
    approvalRequired: bool,
    approvalAmountRequired: string,
    approvalContractAddress: string,
    approvalTxNonce: string,
    approvalGasPrice: string,
    approvalGasFeeMode: int,
    approvalMaxFeesPerGas: string,
    approvalBaseFee: string,
    approvalPriorityFee: string,
    approvalGasAmount: string,
    approvalEstimatedTime: int,
    approvalFee: string,
    approvalL1Fee: string
  ): PathItem =
    new(result, delete)
    result.setup(
      processorName,
      fromChain,
      fromChainEIP1559Compliant,
      fromChainNoBaseFee,
      fromChainNoPriorityFee,
      toChain,
      fromToken,
      toToken,
      amountIn,
      amountInLocked,
      amountOut,
      suggestedNonEIP1559GasPrice,
      suggestedNonEIP1559EstimatedTime,
      suggestedMaxFeesPerGasLowLevel,
      suggestedPriorityFeePerGasLowLevel,
      suggestedEstimatedTimeLowLevel,
      suggestedMaxFeesPerGasMediumLevel,
      suggestedPriorityFeePerGasMediumLevel,
      suggestedEstimatedTimeMediumLevel,
      suggestedMaxFeesPerGasHighLevel,
      suggestedPriorityFeePerGasHighLevel,
      suggestedEstimatedTimeHighLevel,
      suggestedMinPriorityFee,
      suggestedMaxPriorityFee,
      currentBaseFee,
      suggestedTxNonce,
      suggestedTxGasAmount,
      suggestedApprovalTxNonce,
      suggestedApprovalGasAmount,
      txNonce,
      txGasPrice,
      txGasFeeMode,
      txMaxFeesPerGas,
      txBaseFee,
      txPriorityFee,
      txGasAmount,
      txBonderFees,
      txTokenFees,
      txEstimatedTime,
      txFee,
      txL1Fee,
      txTotalFee,
      approvalRequired,
      approvalAmountRequired,
      approvalContractAddress,
      approvalTxNonce,
      approvalGasPrice,
      approvalGasFeeMode,
      approvalMaxFeesPerGas,
      approvalBaseFee,
      approvalPriorityFee,
      approvalGasAmount,
      approvalEstimatedTime,
      approvalFee,
      approvalL1Fee)

  proc `$`*(self: PathItem): string =
    result = "PathItem("
    result &= "\nprocessorName: " & $self.processorName
    result &= "\nfromChain: " & $self.fromChain
    result &= "\nfromChainEIP1559Compliant: " & $self.fromChainEIP1559Compliant
    result &= "\nfromChainNoBaseFee: " & $self.fromChainNoBaseFee
    result &= "\nfromChainNoPriorityFee: " & $self.fromChainNoPriorityFee
    result &= "\ntoChain: " & $self.toChain
    result &= "\nfromToken: " & $self.fromToken
    result &= "\ntoToken: " & $self.toToken
    result &= "\namountIn: " & $self.amountIn
    result &= "\namountInLocked: " & $self.amountInLocked
    result &= "\namountOut: " & $self.amountOut
    result &= "\nsuggestedNonEIP1559GasPrice: " & $self.suggestedNonEIP1559GasPrice
    result &= "\nsuggestedNonEIP1559EstimatedTime: " & $self.suggestedNonEIP1559EstimatedTime
    result &= "\nsuggestedMaxFeesPerGasLowLevel: " & $self.suggestedMaxFeesPerGasLowLevel
    result &= "\nsuggestedPriorityFeePerGasLowLevel: " & $self.suggestedPriorityFeePerGasLowLevel
    result &= "\nsuggestedEstimatedTimeLowLevel: " & $self.suggestedEstimatedTimeLowLevel
    result &= "\nsuggestedMaxFeesPerGasMediumLevel: " & $self.suggestedMaxFeesPerGasMediumLevel
    result &= "\nsuggestedPriorityFeePerGasMediumLevel: " & $self.suggestedPriorityFeePerGasMediumLevel
    result &= "\nsuggestedEstimatedTimeMediumLevel: " & $self.suggestedEstimatedTimeMediumLevel
    result &= "\nsuggestedMaxFeesPerGasHighLevel: " & $self.suggestedMaxFeesPerGasHighLevel
    result &= "\nsuggestedPriorityFeePerGasHighLevel: " & $self.suggestedPriorityFeePerGasHighLevel
    result &= "\nsuggestedEstimatedTimeHighLevel: " & $self.suggestedEstimatedTimeHighLevel
    result &= "\nsuggestedMinPriorityFee: " & $self.suggestedMinPriorityFee
    result &= "\nsuggestedMaxPriorityFee: " & $self.suggestedMaxPriorityFee
    result &= "\ncurrentBaseFee: " & $self.currentBaseFee
    result &= "\nsuggestedTxNonce: " & $self.suggestedTxNonce
    result &= "\nsuggestedTxGasAmount: " & $self.suggestedTxGasAmount
    result &= "\nsuggestedApprovalTxNonce: " & $self.suggestedApprovalTxNonce
    result &= "\nsuggestedApprovalGasAmount: " & $self.suggestedApprovalGasAmount
    result &= "\ntxNonce: " & $self.txNonce
    result &= "\ntxGasPrice: " & $self.txGasPrice
    result &= "\ntxGasFeeMode: " & $self.txGasFeeMode
    result &= "\ntxMaxFeesPerGas: " & $self.txMaxFeesPerGas
    result &= "\ntxBaseFee: " & $self.txBaseFee
    result &= "\ntxPriorityFee: " & $self.txPriorityFee
    result &= "\ntxGasAmount: " & $self.txGasAmount
    result &= "\ntxBonderFees: " & $self.txBonderFees
    result &= "\ntxTokenFees: " & $self.txTokenFees
    result &= "\ntxEstimatedTime: " & $self.txEstimatedTime
    result &= "\ntxFee: " & $self.txFee
    result &= "\ntxL1Fee: " & $self.txL1Fee
    result &= "\ntxTotalFee: " & $self.txTotalFee
    result &= "\napprovalRequired: " & $self.approvalRequired
    result &= "\napprovalAmountRequired: " & $self.approvalAmountRequired
    result &= "\napprovalContractAddress: " & $self.approvalContractAddress
    result &= "\napprovalTxNonce: " & $self.approvalTxNonce
    result &= "\napprovalGasPrice: " & $self.approvalGasPrice
    result &= "\napprovalGasFeeMode: " & $self.approvalGasFeeMode
    result &= "\napprovalMaxFeesPerGas: " & $self.approvalMaxFeesPerGas
    result &= "\napprovalBaseFee: " & $self.approvalBaseFee
    result &= "\napprovalPriorityFee: " & $self.approvalPriorityFee
    result &= "\napprovalGasAmount: " & $self.approvalGasAmount
    result &= "\napprovalEstimatedTime: " & $self.approvalEstimatedTime
    result &= "\napprovalFee: " & $self.approvalFee
    result &= "\napprovalL1Fee: " & $self.approvalL1Fee
    result &= ")"

  proc processorName*(self: PathItem): string =
    return self.processorName

  proc fromChain*(self: PathItem): int =
    return self.fromChain

  proc fromChainEIP1559Compliant*(self: PathItem): bool =
    return self.fromChainEIP1559Compliant

  proc fromChainNoBaseFee*(self: PathItem): bool =
    return self.fromChainNoBaseFee

  proc fromChainNoPriorityFee*(self: PathItem): bool =
    return self.fromChainNoPriorityFee

  proc toChain*(self: PathItem): int =
    return self.toChain

  proc fromToken*(self: PathItem): string =
    return self.fromToken

  proc toToken*(self: PathItem): string =
    return self.toToken

  proc amountIn*(self: PathItem): string =
    return self.amountIn

  proc amountInLocked*(self: PathItem): bool =
    return self.amountInLocked

  proc amountOut*(self: PathItem): string =
    return self.amountOut

  proc suggestedNonEIP1559GasPrice*(self: PathItem): string =
    return self.suggestedNonEIP1559GasPrice

  proc suggestedNonEIP1559EstimatedTime*(self: PathItem): int =
    return self.suggestedNonEIP1559EstimatedTime

  proc suggestedMaxFeesPerGasLowLevel*(self: PathItem): string =
    return self.suggestedMaxFeesPerGasLowLevel

  proc suggestedPriorityFeePerGasLowLevel*(self: PathItem): string =
    return self.suggestedPriorityFeePerGasLowLevel

  proc suggestedEstimatedTimeLowLevel*(self: PathItem): int =
    return self.suggestedEstimatedTimeLowLevel

  proc suggestedMaxFeesPerGasMediumLevel*(self: PathItem): string =
    return self.suggestedMaxFeesPerGasMediumLevel

  proc suggestedPriorityFeePerGasMediumLevel*(self: PathItem): string =
    return self.suggestedPriorityFeePerGasMediumLevel

  proc suggestedEstimatedTimeMediumLevel*(self: PathItem): int =
    return self.suggestedEstimatedTimeMediumLevel

  proc suggestedMaxFeesPerGasHighLevel*(self: PathItem): string =
    return self.suggestedMaxFeesPerGasHighLevel

  proc suggestedPriorityFeePerGasHighLevel*(self: PathItem): string =
    return self.suggestedPriorityFeePerGasHighLevel

  proc suggestedEstimatedTimeHighLevel*(self: PathItem): int =
    return self.suggestedEstimatedTimeHighLevel

  proc suggestedMinPriorityFee*(self: PathItem): string =
    return self.suggestedMinPriorityFee

  proc suggestedMaxPriorityFee*(self: PathItem): string =
    return self.suggestedMaxPriorityFee

  proc currentBaseFee*(self: PathItem): string =
    return self.currentBaseFee

  proc suggestedTxNonce*(self: PathItem): string =
    return self.suggestedTxNonce

  proc suggestedTxGasAmount*(self: PathItem): string =
    return self.suggestedTxGasAmount

  proc suggestedApprovalTxNonce*(self: PathItem): string =
    return self.suggestedApprovalTxNonce

  proc suggestedApprovalGasAmount*(self: PathItem): string =
    return self.suggestedApprovalGasAmount

  proc txNonce*(self: PathItem): string =
    return self.txNonce

  proc txGasPrice*(self: PathItem): string =
    return self.txGasPrice

  proc txGasFeeMode*(self: PathItem): int =
    return self.txGasFeeMode

  proc txMaxFeesPerGas*(self: PathItem): string =
    return self.txMaxFeesPerGas

  proc txBaseFee*(self: PathItem): string =
    return self.txBaseFee

  proc txPriorityFee*(self: PathItem): string =
    return self.txPriorityFee

  proc txGasAmount*(self: PathItem): string =
    return self.txGasAmount

  proc txBonderFees*(self: PathItem): string =
    return self.txBonderFees

  proc txTokenFees*(self: PathItem): string =
    return self.txTokenFees

  proc txEstimatedTime*(self: PathItem): int =
    return self.txEstimatedTime

  proc txFee*(self: PathItem): string =
    return self.txFee

  proc txL1Fee*(self: PathItem): string =
    return self.txL1Fee

  proc txTotalFee*(self: PathItem): string =
    return self.txTotalFee

  proc approvalRequired*(self: PathItem): bool =
    return self.approvalRequired

  proc approvalAmountRequired*(self: PathItem): string =
    return self.approvalAmountRequired

  proc approvalContractAddress*(self: PathItem): string =
    return self.approvalContractAddress

  proc approvalTxNonce*(self: PathItem): string =
    return self.approvalTxNonce

  proc approvalGasPrice*(self: PathItem): string =
    return self.approvalGasPrice

  proc approvalGasFeeMode*(self: PathItem): int =
    return self.approvalGasFeeMode

  proc approvalMaxFeesPerGas*(self: PathItem): string =
    return self.approvalMaxFeesPerGas

  proc approvalBaseFee*(self: PathItem): string =
    return self.approvalBaseFee

  proc approvalPriorityFee*(self: PathItem): string =
    return self.approvalPriorityFee

  proc approvalGasAmount*(self: PathItem): string =
    return self.approvalGasAmount

  proc approvalEstimatedTime*(self: PathItem): int =
    return self.approvalEstimatedTime

  proc approvalFee*(self: PathItem): string =
    return self.approvalFee

  proc approvalL1Fee*(self: PathItem): string =
    return self.approvalL1Fee

  proc estimatedTime*(self: PathItem): int =
    if self.processorName in [wallet_constants.PROCESSOR_NAME_SWAP_PARASWAP,
                              wallet_constants.PROCESSOR_NAME_SWAP_LIFI,
                              wallet_constants.PROCESSOR_NAME_SWAP_RELAY]:
      return self.txEstimatedTime + self.approvalEstimatedTime
    if self.processorName == wallet_constants.PROCESSOR_NAME_BRIDGE_HOP:
      return self.txEstimatedTime + 1
    return self.txEstimatedTime

  proc delete*(self: PathItem) =
    self.QObject.delete

  proc setup*(self: PathItem,
    processorName: string,
    fromChain: int,
    fromChainEIP1559Compliant: bool,
    fromChainNoBaseFee: bool,
    fromChainNoPriorityFee: bool,
    toChain: int,
    fromToken: string,
    toToken: string,
    amountIn: string,
    amountInLocked: bool,
    amountOut: string,
    suggestedNonEIP1559GasPrice: string,
    suggestedNonEIP1559EstimatedTime: int,
    suggestedMaxFeesPerGasLowLevel: string,
    suggestedPriorityFeePerGasLowLevel: string,
    suggestedEstimatedTimeLowLevel: int,
    suggestedMaxFeesPerGasMediumLevel: string,
    suggestedPriorityFeePerGasMediumLevel: string,
    suggestedEstimatedTimeMediumLevel: int,
    suggestedMaxFeesPerGasHighLevel: string,
    suggestedPriorityFeePerGasHighLevel: string,
    suggestedEstimatedTimeHighLevel: int,
    suggestedMinPriorityFee: string,
    suggestedMaxPriorityFee: string,
    currentBaseFee: string,
    suggestedTxNonce: string,
    suggestedTxGasAmount: string,
    suggestedApprovalTxNonce: string,
    suggestedApprovalGasAmount: string,
    txNonce: string,
    txGasPrice: string,
    txGasFeeMode: int,
    txMaxFeesPerGas: string,
    txBaseFee: string,
    txPriorityFee: string,
    txGasAmount: string,
    txBonderFees: string,
    txTokenFees: string,
    txEstimatedTime: int,
    txFee: string,
    txL1Fee: string,
    txTotalFee: string,
    approvalRequired: bool,
    approvalAmountRequired: string,
    approvalContractAddress: string,
    approvalTxNonce: string,
    approvalGasPrice: string,
    approvalGasFeeMode: int,
    approvalMaxFeesPerGas: string,
    approvalBaseFee: string,
    approvalPriorityFee: string,
    approvalGasAmount: string,
    approvalEstimatedTime: int,
    approvalFee: string,
    approvalL1Fee: string
  ) =
    self.QObject.setup
    self.processorName = processorName
    self.fromChain = fromChain
    self.fromChainEIP1559Compliant = fromChainEIP1559Compliant
    self.fromChainNoBaseFee = fromChainNoBaseFee
    self.fromChainNoPriorityFee = fromChainNoPriorityFee
    self.toChain = toChain
    self.fromToken = fromToken
    self.toToken = toToken
    self.amountIn = amountIn
    self.amountInLocked = amountInLocked
    self.amountOut = amountOut
    self.suggestedNonEIP1559GasPrice = suggestedNonEIP1559GasPrice
    self.suggestedNonEIP1559EstimatedTime = suggestedNonEIP1559EstimatedTime
    self.suggestedMaxFeesPerGasLowLevel = suggestedMaxFeesPerGasLowLevel
    self.suggestedPriorityFeePerGasLowLevel = suggestedPriorityFeePerGasLowLevel
    self.suggestedEstimatedTimeLowLevel = suggestedEstimatedTimeLowLevel
    self.suggestedMaxFeesPerGasMediumLevel = suggestedMaxFeesPerGasMediumLevel
    self.suggestedPriorityFeePerGasMediumLevel = suggestedPriorityFeePerGasMediumLevel
    self.suggestedEstimatedTimeMediumLevel = suggestedEstimatedTimeMediumLevel
    self.suggestedMaxFeesPerGasHighLevel = suggestedMaxFeesPerGasHighLevel
    self.suggestedPriorityFeePerGasHighLevel = suggestedPriorityFeePerGasHighLevel
    self.suggestedEstimatedTimeHighLevel = suggestedEstimatedTimeHighLevel
    self.suggestedMinPriorityFee = suggestedMinPriorityFee
    self.suggestedMaxPriorityFee = suggestedMaxPriorityFee
    self.currentBaseFee = currentBaseFee
    self.suggestedTxNonce = suggestedTxNonce
    self.suggestedTxGasAmount = suggestedTxGasAmount
    self.suggestedApprovalTxNonce = suggestedApprovalTxNonce
    self.suggestedApprovalGasAmount = suggestedApprovalGasAmount
    self.txNonce = txNonce
    self.txGasPrice = txGasPrice
    self.txGasFeeMode = txGasFeeMode
    self.txMaxFeesPerGas = txMaxFeesPerGas
    self.txBaseFee = txBaseFee
    self.txPriorityFee = txPriorityFee
    self.txGasAmount = txGasAmount
    self.txBonderFees = txBonderFees
    self.txTokenFees = txTokenFees
    self.txEstimatedTime = txEstimatedTime
    self.txFee = txFee
    self.txL1Fee = txL1Fee
    self.txTotalFee = txTotalFee
    self.approvalRequired = approvalRequired
    self.approvalAmountRequired = approvalAmountRequired
    self.approvalContractAddress = approvalContractAddress
    self.approvalTxNonce = approvalTxNonce
    self.approvalGasPrice = approvalGasPrice
    self.approvalGasFeeMode = approvalGasFeeMode
    self.approvalMaxFeesPerGas = approvalMaxFeesPerGas
    self.approvalBaseFee = approvalBaseFee
    self.approvalPriorityFee = approvalPriorityFee
    self.approvalGasAmount = approvalGasAmount
    self.approvalEstimatedTime = approvalEstimatedTime
    self.approvalFee = approvalFee
    self.approvalL1Fee = approvalL1Fee
