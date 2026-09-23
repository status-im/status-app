import unittest, json, strutils
import nimqml

import app/core/eventemitter
import app/modules/shared_modules/wallet_connect/controller

QtObject:
  type Receiver = ref object of QObject
    requestedReasons: seq[string]
    results: seq[tuple[topic: string, id: string, data: string]]

  proc delete(self: Receiver)

  proc newReceiver(): Receiver =
    new(result, delete)
    result.QObject.setup

  proc delete(self: Receiver) =
    self.QObject.delete

  proc onSigningRequested*(self: Receiver, reason: string, keyUid: string, hash: string, path: string, address: string) {.slot.} =
    self.requestedReasons.add(reason)

  proc onSigningResultReceived*(self: Receiver, topic: string, id: string, data: string) {.slot.} =
    self.results.add((topic, id, data))

const
  Topic = "topic1"
  Id = "42"
  Address = "0x0000000000000000000000000000000000000001"
  ChainId = 1
  TxJson = """{"from":"0x0000000000000000000000000000000000000001","to":"0x0000000000000000000000000000000000000002","value":"0x1"}"""
  TxHash = "0x0e0b6a0f3a7f5d6a47c4bf8e7d6e2b4e3f0a1c2d3e4f5a6b7c8d9e0f1a2b3c4d"
  SentTxHash = "0xabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabca"

let validSignature = "0x" & repeat("11", 32) & repeat("22", 32) & "1b"
let buildOk = $(%*{"txToSign": TxHash, "txData": {"nonce": "0x1", "gas": "0x5208"}})

suite "wallet connect controller transactions":
  setup:
    var works: seq[WcTxWork] = @[]
    let ctrl = newController(nil, nil, createEventEmitter(), WcTxCalls(
      resolveSigningParams: proc(address: string): tuple[keyUid: string, path: string, ok: bool] =
        ("uid", "m/44'/60'/0'/0/0", true),
      startTxWork: proc(work: WcTxWork) =
        works.add(work)))
    let receiver = newReceiver()
    discard QObject.connect(ctrl, signingRequested, receiver, onSigningRequested)
    discard QObject.connect(ctrl, signingResultReceived, receiver, onSigningResultReceived)

  teardown:
    receiver.delete()
    ctrl.delete()

  test "sendTransaction builds off the GUI thread and requests the signature on completion":
    ctrl.sendTransaction(Topic, Id, Address, ChainId, TxJson)

    check works.len == 1
    check works[0].kind == wtwBuild
    check works[0].chainId == ChainId
    check works[0].txJson == TxJson
    check receiver.requestedReasons.len == 0
    check receiver.results.len == 0

    ctrl.onTxWorkDone(works[0].key, buildOk)

    check receiver.requestedReasons.len == 1
    check receiver.results.len == 0

  test "a signed sendTransaction is broadcast off the GUI thread":
    ctrl.sendTransaction(Topic, Id, Address, ChainId, TxJson)
    check works.len == 1
    ctrl.onTxWorkDone(works[0].key, buildOk)
    check receiver.requestedReasons.len == 1

    ctrl.onSigningResult(receiver.requestedReasons[0], validSignature)

    check works.len == 2
    check works[1].kind == wtwSend
    check works[1].chainId == ChainId
    check works[1].signature.len > 0
    check receiver.results.len == 0

    ctrl.onTxWorkDone(works[1].key, $(%*{"data": SentTxHash}))

    check receiver.results == @[(Topic, Id, SentTxHash)]

  test "a signed signTransaction builds the raw transaction off the GUI thread":
    ctrl.signTransaction(Topic, Id, Address, ChainId, TxJson)
    check works.len == 1
    check works[0].kind == wtwBuild
    ctrl.onTxWorkDone(works[0].key, buildOk)
    check receiver.requestedReasons.len == 1

    ctrl.onSigningResult(receiver.requestedReasons[0], validSignature)

    check works.len == 2
    check works[1].kind == wtwBuildRaw
    check receiver.results.len == 0

    ctrl.onTxWorkDone(works[1].key, $(%*{"data": "0xf86b01"}))

    check receiver.results == @[(Topic, Id, "0xf86b01")]

  test "a repeated request while one is in flight starts no second build":
    ctrl.sendTransaction(Topic, Id, Address, ChainId, TxJson)
    ctrl.sendTransaction(Topic, Id, Address, ChainId, TxJson)

    check works.len == 1
    check receiver.results.len == 0

  test "a failed build reports an empty result":
    ctrl.sendTransaction(Topic, Id, Address, ChainId, TxJson)
    check works.len == 1

    ctrl.onTxWorkDone(works[0].key, $(%*{"error": "nonce fetch failed"}))

    check receiver.requestedReasons.len == 0
    check receiver.results == @[(Topic, Id, "")]

  test "a cancelled signature reports an empty result without starting work":
    ctrl.sendTransaction(Topic, Id, Address, ChainId, TxJson)
    check works.len == 1
    ctrl.onTxWorkDone(works[0].key, buildOk)
    check receiver.requestedReasons.len == 1

    ctrl.onSigningResult(receiver.requestedReasons[0], "")

    check works.len == 1
    check receiver.results == @[(Topic, Id, "")]

  test "results for unknown requests are ignored":
    ctrl.onTxWorkDone("other|1", $(%*{"data": SentTxHash}))

    check receiver.results.len == 0
