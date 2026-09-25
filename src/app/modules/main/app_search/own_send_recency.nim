import app_service/service/message/dto/message

# Own-send recency (see CONTEXT.md "Destination picker"): the newest timestamp
# among the user's own messages in a batch. Batches are not ordered, so every
# message is inspected and each contributes its own timestamp.

proc latestOwnSendTimestamp*(messages: openArray[MessageDto], myPubKey: string): int =
  result = 0
  for m in messages:
    if m.`from` == myPubKey and m.timestamp.int > result:
      result = m.timestamp.int

proc newestMessage*(messages: openArray[MessageDto]): MessageDto =
  result = messages[0]
  for m in messages:
    if m.timestamp > result.timestamp:
      result = m
