import unittest

import app_service/service/activity_center/count_refresh_generation

suite "activity center count refresh generation":
  test "first request starts and a concurrent request coalesces":
    var state = initCountRefreshGenerationState()

    let first = state.requestRefresh()
    let second = state.requestRefresh()

    check first.shouldStart
    check first.generation == 1
    check not second.shouldStart
    check second.generation == 2
    check state.inFlight

  test "stale completion refires the newest generation once":
    var state = initCountRefreshGenerationState()
    let first = state.requestRefresh()
    discard state.requestRefresh()

    let staleCompletion = state.onCompletion(first.generation)
    check staleCompletion.action == crcaDropAndRefire
    check staleCompletion.generation == 2
    check state.inFlight

    let newestCompletion = state.onCompletion(staleCompletion.generation)
    check newestCompletion.action == crcaApply
    check not state.inFlight

  test "a request after completion starts immediately":
    var state = initCountRefreshGenerationState()
    let first = state.requestRefresh()
    discard state.onCompletion(first.generation)

    let second = state.requestRefresh()

    check second.shouldStart
    check second.generation == 2

  test "current generation safely resolves an undecodable completion":
    var state = initCountRefreshGenerationState()
    discard state.requestRefresh()

    let completion = state.onCompletion(state.currentGeneration)

    check completion.action == crcaApply
    check not state.inFlight