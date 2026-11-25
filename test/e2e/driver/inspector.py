"""Connection to the inspector plugin loaded into the app.

Wire format: one JSON object per line, ``{"id", "command", "params"}``, and one JSON line back.
"""

import itertools
import json
import socket


class InspectorError(RuntimeError):
    """The plugin answered with an error, or the connection closed."""


class Inspector:
    def __init__(self, port, timeout_sec=30.0):
        self._socket = socket.create_connection(("127.0.0.1", port), timeout=timeout_sec)
        self._file = self._socket.makefile("rwb")
        self._ids = itertools.count(1)

    def send(self, command, **params):
        if self._file.closed:
            raise ConnectionError(f"{command}: connection to the app is closed")
        request_id = next(self._ids)
        request = {"id": request_id, "command": command, "params": params}
        try:
            self._file.write(json.dumps(request).encode() + b"\n")
            self._file.flush()
            line = self._file.readline()
        except TimeoutError:
            # The late reply would otherwise be read as the answer to the next command.
            self.close()
            raise
        if not line:
            raise InspectorError(f"{command}: connection closed")
        reply = json.loads(line)
        if reply.get("id") != request_id:
            self.close()
            raise ConnectionError(f"{command}: got the reply to request {reply.get('id')}, expected {request_id}")
        if "error" in reply:
            raise InspectorError(f"{command}: {reply['error']}")
        return reply

    def properties(self, object_id):
        reply = self.send("getProperties", objectId=object_id)
        return {p["name"]: p["value"] for p in reply["properties"]}

    def evaluate(self, expression, object_id):
        return self.send("evaluate", expression=expression, objectId=object_id)["result"]

    def close(self):
        try:
            self._file.close()
        finally:
            self._socket.close()
