import unittest

import app/modules/main/app_search/own_send_recency
import app_service/service/message/dto/message

const me = "0xme"
const peer = "0xpeer"

proc msg(sender: string, ts: int64): MessageDto =
  result = MessageDto()
  result.`from` = sender
  result.timestamp = ts

suite "own send recency":
  test "newest own message wins regardless of batch order":
    let batch = @[msg(peer, 900), msg(me, 300), msg(me, 700), msg(peer, 100)]
    check latestOwnSendTimestamp(batch, me) == 700

  test "no own message yields zero, not the peer's timestamp":
    check latestOwnSendTimestamp(@[msg(peer, 900)], me) == 0
    check latestOwnSendTimestamp(@[], me) == 0

  test "newest message is picked by timestamp, not position":
    let batch = @[msg(peer, 100), msg(me, 900), msg(peer, 500)]
    check newestMessage(batch).timestamp == 900
