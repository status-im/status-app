## Pure decode-and-release step for the async missing-tokens batch fetch.
##
## The GUI slot (onAsyncFetchMissingTokensDone) receives the worker's finished
## batch as a string envelope; this module decodes it and releases the batch's
## keys from the in-flight set. Split out of the slot so the release contract is
## unit-testable without a live Service or backend — same pattern as
## token_pending_fetch / token_apply_builder.

import json_serialization

import dto/token
import token_pending_fetch

type FetchMissingTokensResponse* = object
  requestedKeys*: seq[string] # echoed back so the slot knows which keys were asked for
  tokens*: seq[TokenDtoSafe]  # the subset the backend actually resolved
  error*: string

proc decodeAndCompleteBatch*(fetch: var PendingTokenFetch, response: string):
    tuple[env: FetchMissingTokensResponse, decodeError: string] =
  ## Decode a finished batch's envelope and release its keys from the in-flight
  ## set. Returns the decoded envelope, or a non-empty decodeError when the
  ## envelope itself was undecodable. The keys are released on EVERY outcome:
  ## a key left in flight can never re-enqueue, so it would wedge (stop
  ## resolving) for the rest of the session.
  try:
    result.env = Json.decode(response, FetchMissingTokensResponse, allowUnknownFields = true)
    fetch.completeBatch(result.env.requestedKeys)
  except Exception as e:
    # The batch's own key list is unknown when its envelope is undecodable, so
    # drain the whole in-flight set (see drainInFlight for why that is safe).
    fetch.drainInFlight()
    result.decodeError = e.msg
