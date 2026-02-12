import options, chronicles
import json, json_serialization
import core, response_type

from gen import rpc

rpc(hashMessageEIP191, "wallet"):
  message: string