{.used.}

import std/strformat

type
  RpcException* = object of CatchableError

type
  RpcError* = ref object
    code*: int
    message*: string

type
  RpcResponse*[T] = object
    jsonrpc*: string
    result*: T
    id*: int
    error*: RpcError

proc `$`*(self: RpcError): string =
  try:
    fmt"""RpcError(
      code: {self.code},
      message: {self.message},
      )"""
  except ValueError:
    raiseAssert "static fmt"

