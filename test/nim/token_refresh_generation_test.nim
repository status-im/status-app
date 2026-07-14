## Unit tests for the pure refresh-generation coordinator.
## Coalesces the token service's heavy async tasks: while one is in flight new
## triggers do not start another; the in-flight completion re-fires once if newer
## triggers arrived, and stale completions are dropped without applying. Net: N
## queued triggers -> exactly one apply of the newest data. No Qt/backend.

import unittest

import app_service/service/token/token_refresh_generation

suite "refresh generation — starting and coalescing":
  test "the first trigger starts a task stamped with generation 1":
    var g = initRefreshGenerationState()
    let r = g.requestRefresh()
    check r.shouldStart
    check r.gen == 1
    check g.inFlight

  test "a trigger while a task is in flight does not start another":
    var g = initRefreshGenerationState()
    discard g.requestRefresh()          # starts gen 1
    let r = g.requestRefresh()          # in flight -> coalesce
    check not r.shouldStart
    check r.gen == 2                     # desired generation still advances
    check g.inFlight

suite "refresh generation — completion":
  test "completing the latest generation applies and clears in-flight":
    var g = initRefreshGenerationState()
    let r = g.requestRefresh()          # gen 1, in flight
    let c = g.onCompletion(r.gen)
    check c.action == rcaApply
    check not g.inFlight

  test "a trigger during flight makes the stale completion drop and re-fire once":
    var g = initRefreshGenerationState()
    let r1 = g.requestRefresh()         # gen 1
    discard g.requestRefresh()          # gen 2, coalesced
    let c1 = g.onCompletion(r1.gen)     # gen 1 completes while gen 2 desired
    check c1.action == rcaDropAndRefire
    check c1.gen == 2                    # re-fire with the newest generation
    check g.inFlight
    let c2 = g.onCompletion(c1.gen)     # gen 2 completes, nothing newer
    check c2.action == rcaApply
    check not g.inFlight

  test "three rapid triggers yield exactly one apply":
    var g = initRefreshGenerationState()
    let r1 = g.requestRefresh()
    discard g.requestRefresh()
    discard g.requestRefresh()          # desired = 3, only gen 1 started
    var applies = 0
    var c = g.onCompletion(r1.gen)      # gen 1 stale -> drop + refire gen 3
    if c.action == rcaApply: inc applies
    check c.action == rcaDropAndRefire
    c = g.onCompletion(c.gen)           # gen 3 completes
    if c.action == rcaApply: inc applies
    check applies == 1

  test "a fresh trigger after completion starts a new task":
    var g = initRefreshGenerationState()
    let r1 = g.requestRefresh()
    discard g.onCompletion(r1.gen)      # applied, idle
    let r2 = g.requestRefresh()
    check r2.shouldStart
    check r2.gen == 2

  test "an undecodable completion, replayed via currentGeneration, does not re-fire forever":
    # The service passes currentGeneration() when a completion cannot be decoded.
    # With no newer trigger this must resolve to apply (go idle), not loop.
    var g = initRefreshGenerationState()
    discard g.requestRefresh()          # gen 1 in flight
    check g.currentGeneration == 1
    let c = g.onCompletion(g.currentGeneration)
    check c.action == rcaApply           # no newer trigger -> idle, bounded
    check not g.inFlight

  test "an undecodable completion still re-fires once when newer triggers arrived":
    var g = initRefreshGenerationState()
    discard g.requestRefresh()          # gen 1 in flight
    discard g.requestRefresh()          # gen 2 desired
    let c = g.onCompletion(g.currentGeneration)  # currentGeneration == 1 < 2
    check c.action == rcaDropAndRefire
    check c.gen == 2
