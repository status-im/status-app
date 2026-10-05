import unittest

import app_service/service/transaction/dto

suite "transaction toast asset key":
  test "a collectible keeps the requested key, which carries its token id":
    check toastAssetKey(SendType.ERC721Transfer, "11155111-0xabc-61", "11155111-0xabc") == "11155111-0xabc-61"
    check toastAssetKey(SendType.ERC1155Transfer, "1-0xabc-7", "1-0xabc") == "1-0xabc-7"

  test "a token uses the key of the sent transaction":
    check toastAssetKey(SendType.Transfer, "1-0xrequested", "1-0xsent") == "1-0xsent"

  test "a transaction that wasn't sent keeps the requested key":
    check toastAssetKey(SendType.Transfer, "1-0xrequested", "") == "1-0xrequested"
