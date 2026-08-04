import strutils, stint, chronicles, algorithm

import app_service/common/conversion

import ./dto, ./dtoV2

proc sortAsc[T](t1, t2: T): int =
  if (t1.fromNetwork.chainId > t2.fromNetwork.chainId): return 1
  elif (t1.fromNetwork.chainId < t2.fromNetwork.chainId): return -1
  else: return 0

proc estimatedTimeFlagFromSeconds(seconds: int): int =
  if seconds <= 0:
    return 0 # Unknown
  elif seconds < 60:
    return 1 # LessThanOneMin
  elif seconds < 180:
    return 2 # LessThanThreeMins
  elif seconds <= 300:
    return 3 # LessThanFiveMins
  else:
    return 4 # MoreThanFiveMins

proc convertToOldRoute*(route: seq[TransactionPathDtoV2]): seq[TransactionPathDto] =
  const
    defaultDecimals = 1
    gweiDecimals = 9
    ethDecimals = 18
  for p in route:
    var
      fees = SuggestedFeesDto()
      trPath = TransactionPathDto()

    try:
      # prepare fees
      fees.gasPrice = 0
      var value = conversion.wei2Eth(input = p.txBaseFee, decimals = gweiDecimals)
      fees.baseFee = parseFloat(value)
      value = conversion.wei2Eth(input = p.txPriorityFee, decimals = gweiDecimals)
      fees.maxPriorityFeePerGas = parseFloat(value)
      value = conversion.wei2Eth(input = p.suggestedLevelsForMaxFeesPerGas.low, decimals = gweiDecimals)
      fees.maxFeePerGasL = parseFloat(value)
      value = conversion.wei2Eth(input = p.suggestedLevelsForMaxFeesPerGas.medium, decimals = gweiDecimals)
      fees.maxFeePerGasM = parseFloat(value)
      value = conversion.wei2Eth(input = p.suggestedLevelsForMaxFeesPerGas.high, decimals = gweiDecimals)
      fees.maxFeePerGasH = parseFloat(value)
      value = conversion.wei2Eth(input = p.txL1Fee, decimals = gweiDecimals)
      fees.l1GasFee = parseFloat(value)
      fees.eip1559Enabled = true

      # prepare tx path
      trPath.bridgeName = p.processorName
      trPath.tool = p.tool
      trPath.fromNetwork = p.fromChain
      trPath.toNetwork = p.toChain
      trPath.fromToken = p.fromToken
      trPath.toToken = p.toToken
      trPath.gasFees = fees
      # trPath.cost = not in use for old approach in the desktop app
      var decimals = defaultDecimals
      if(p.fromToken.decimals != 0):
        decimals = p.fromToken.decimals
      value = conversion.wei2Eth(input = p.txTokenFees, decimals = decimals)
      trPath.tokenFees = parseFloat(value)
      value = conversion.wei2Eth(input = p.txBonderFees, decimals = decimals)
      trPath.bonderFees = value
      trPath.txBonderFees = p.txBonderFees
      trPath.tokenFees += parseFloat(value) # we add bonder fees to the token fees cause in the UI, atm, we show only token fees
      trPath.maxAmountIn = stint.fromHex(UInt256, "0x0")
      trPath.amountIn = p.amountIn
      trPath.amountOut = p.amountOut
      trPath.approvalRequired = p.approvalRequired
      trPath.approvalAmountRequired = p.approvalAmountRequired
      trPath.approvalContractAddress = p.approvalContractAddress
      trPath.amountInLocked = p.amountInLocked
      trPath.gasAmount = p.txGasAmount

      # The approval and main tx run sequentially, so sum their (seconds) estimates before bucketing.
      # approvalEstimatedTime is 0 when no approval is needed.
      trPath.estimatedTime = estimatedTimeFlagFromSeconds(p.txEstimatedTime + p.approvalEstimatedTime)

      value = conversion.wei2Eth(p.suggestedLevelsForMaxFeesPerGas.medium,  decimals = ethDecimals)
      trPath.approvalGasFees = parseFloat(value) * float64(p.approvalGasAmount)
      value = conversion.wei2Eth(p.approvalL1Fee,  decimals = ethDecimals)
      trPath.approvalGasFees += parseFloat(value)

      trPath.isFirstSimpleTx = false
      trPath.isFirstBridgeTx = false
    except Exception as e:
      error "Error converting to old path", msg = e.msg

    # add tx path to the list
    result.add(trPath)

  result.sort(sortAsc[TransactionPathDto])
