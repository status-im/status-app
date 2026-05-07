import json
import json_serialization
from app/core/eventemitter import Args

type
  ContentType* {.pure.} = enum
    NewMessagesMarker = -3
    FetchMoreMessagesButton = -2
    ChatIdentifier = -1
    Unknown = 0
    Message = 1
    Sticker = 2
    Status = 3
    Emoji = 4
    Transaction = 5
    SystemMessageGroup = 6
    Image = 7
    Audio = 8
    Community = 9
    Gap = 10
    ContactRequest = 11
    DiscordMessage = 12
    ContactIdentityVerification = 13
    # Local only
    SystemMessagePinnedMessage = 14
    SystemMessageMutualEventSent = 15
    SystemMessageMutualEventAccepted = 16
    SystemMessageMutualEventRemoved = 17
    BridgeMessage = 18

proc toContentType*(value: int): ContentType =
  try:
    return ContentType(value)
  except RangeDefect:
    return ContentType.Unknown

type
  StatusType* {.pure.} = enum
    Unknown = 0
    Automatic
    DoNotDisturb
    AlwaysOnline
    Inactive

  OnlineStatus* {.pure.} = enum
    Inactive = 0
    Online

proc toOnlineStatus*(statusType: StatusType): OnlineStatus =
  if(statusType == StatusType.AlwaysOnline or statusType == StatusType.Automatic):
    return OnlineStatus.Online
  else:
    return OnlineStatus.Inactive

type MemberRole* {.pure} = enum
  None = 0
  Owner
  ManageUsers
  ModerateContent
  Admin
  TokenMaster

# TODO: consider refactor MembershipRequestState to MembershipState and use both for request to join and kick/ban actions
# Issue: https://github.com/status-im/status-app/issues/11842
type MembershipRequestState* {.pure} = enum
  None = 0,
  Pending = 1,
  Declined = 2,
  Accepted = 3
  Canceled = 4,
  AcceptedPending = 5,
  DeclinedPending = 6,
  AwaitingAddress = 7,
  Banned = 8,
  Kicked = 9,
  BannedPending = 10,
  UnbannedPending = 11,
  KickedPending = 12,
  Unbanned = 13,
  BannedWithAllMessagesDelete = 14

type
  ContractTransactionStatus* {.pure.} = enum
    Failed,
    InProgress,
    Completed

type TokenType* {.pure.} = enum
  Native = 0
  ERC20 = 1,
  ERC721 = 2,
  ERC1155 = 3,
  Unknown = 4,
  ENS = 5

TokenType.configureJsonSerialization(EnumAsNumber)

type RequestToJoinState* {.pure.} = enum
  None = 0
  InProgress
  Requested

type TrustStatus* {.pure.}= enum
  Unknown = 0,
  Trusted = 1,
  Untrustworthy = 2

const SIGNAL_LOCAL_BACKUP_IMPORT_COMPLETED* = "localBackupImportCompletedSignal"

const SIGNAL_MESSENGER_STARTED* = "messengerStartedSignal"

type
  LocalBackupImportArg* = ref object of Args
    error*: string
    response*: JsonNode

  MessengerStartedArgs* = ref object of Args
    error*: string

  # Minimal projection of a ChatMember used to seed the contacts cache with
  # status-go-enriched visual identity. Lives here so the contacts service does
  # not have to import chat/dto.
  MemberSeed* = object
    id*: string
    alias*: string
    colorId*: int
    compressedPubKey*: string
    emojiHash*: string
