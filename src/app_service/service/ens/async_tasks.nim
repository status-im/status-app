#################################################
# Async check for ens username availability
#################################################

type
  CheckEnsAvailabilityTaskArg = ref object of QObjectTaskArg
    ensUsername*: string
    chainId*: int
    isStatus*: bool
    myPublicKey*: string
    myAddresses*: seq[string]

proc checkEnsAvailabilityTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[CheckEnsAvailabilityTaskArg](argEncoded)
  try:
    var desiredEnsUsername = arg.ensUsername & (if(arg.isStatus): ens_utils.STATUS_DOMAIN else: "")

    var availability = ""
    let ownerAddr = ens_utils.ownerOf(arg.chainId, desiredEnsUsername)
    if ownerAddr == "" and arg.isStatus:
      availability = ENS_AVAILABILITY_STATUS_AVAILABLE
    else:
      let ensPubkey = ens_utils.publicKeyOf(arg.chainId, arg.ensUsername)
      let ownerIsAmongMyAddresses = arg.myAddresses.filter(address => cmpIgnoreCase(address, ownerAddr) == 0).len == 1
      if ownerAddr != "":
        if ensPubkey == "" and ownerIsAmongMyAddresses:
          availability = ENS_AVAILABILITY_STATUS_OWNED # "Continuing will connect this username with your chat key."
        elif ensPubkey == arg.myPublicKey:
          availability = ENS_AVAILABILITY_STATUS_CONNECTED
        elif ownerIsAmongMyAddresses:
          availability = ENS_AVAILABILITY_STATUS_CONNECTED_DIFFERENT_KEY #  "Continuing will require a transaction to connect the username with your current chat key.",
        else:
          availability = ENS_AVAILABILITY_STATUS_TAKEN
      else:
        availability = ENS_AVAILABILITY_STATUS_TAKEN

    arg.finish(%*{
      "availability": availability,
      "ownerAddress": ownerAddr
    })
  except Exception as e:
    arg.finish(%*{
      "error": e.msg
    })



#################################################
# Async load ens username details
#################################################

type
  EnsUsernamDetailsTaskArg = ref object of QObjectTaskArg
    ensUsername*: string
    isStatus*: bool
    chainId: int

proc ensUsernameDetailsTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[EnsUsernamDetailsTaskArg](argEncoded)
  try:

    let address = ens_utils.addressOf(arg.chainId, arg.ensUsername)
    let pubkey = ens_utils.publicKeyOf(arg.chainId, arg.ensUsername)

    var expirationTime = 0
    if arg.isStatus:
      expirationTime = ens_utils.getExpirationTime(arg.chainId, arg.ensUsername)

    let responseJson = %* {
      "chainId": arg.chainId,
      "ensUsername": arg.ensUsername,
      "address": address,
      "pubkey": pubkey,
      "isStatus": arg.isStatus,
      "expirationTime": expirationTime
    }
    arg.finish(responseJson)
  except Exception as e:
    arg.finish(%* {
      "chainId": arg.chainId,
      "ensUsername": arg.ensUsername,
      "isStatus": arg.isStatus,
      "error": e.msg,
    })
