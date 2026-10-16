"""Android intents that hand content to Status, sent through Appium."""

import base64
import struct
import zlib

ACTION_SEND = "android.intent.action.SEND"
ACTION_VIEW = "android.intent.action.VIEW"
EXTRA_TEXT = "android.intent.extra.TEXT"
EXTRA_STREAM = "android.intent.extra.STREAM"
FLAG_GRANT_READ_URI_PERMISSION = "0x1"
FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY = "0x100000"
IMAGE_DIR = "/sdcard/Download"
IMAGES_COLLECTION = "content://media/external/images/media"


def package_of(driver) -> str:
    return driver.capabilities.get("appPackage") or "app.status.mobile"


def _start(driver, action: str, *, mime_type=None, uri=None, extras=None, flags=None) -> None:
    # The package, not the activity: Android has to match the intent against
    # the manifest's filters, as it does for the system share sheet.
    args = {"package": package_of(driver), "action": action, "wait": True}
    if mime_type:
        args["mimeType"] = mime_type
    if uri:
        args["uri"] = uri
    if extras:
        args["extras"] = extras
    if flags:
        args["flags"] = flags
    driver.execute_script("mobile: startActivity", args)


def share_text(driver, text: str, flags: str | None = None) -> None:
    _start(driver, ACTION_SEND, mime_type="text/plain", extras=[["s", EXTRA_TEXT, text]], flags=flags)


def share_image(driver, content_uri: str, caption: str | None = None, mime_type: str = "image/png") -> None:
    # The read grant only covers the intent's data URI, so the stream is
    # named there as well as in EXTRA_STREAM.
    extras = [["u", EXTRA_STREAM, content_uri]]
    if caption:
        extras.append(["s", EXTRA_TEXT, caption])
    _start(
        driver, ACTION_SEND, mime_type=mime_type, uri=content_uri, extras=extras,
        flags=FLAG_GRANT_READ_URI_PERMISSION,
    )


def open_link(driver, url: str) -> None:
    _start(driver, ACTION_VIEW, uri=url)


def solid_png(width: int = 64, height: int = 64, rgb=(200, 30, 30)) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + bytes(rgb) * width for _ in range(height))
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


def _shell(driver, command: str, args: list[str]) -> str:
    return driver.execute_script("mobile: shell", {"command": command, "args": args}) or ""


def push_image(driver, name: str, data: bytes | None = None) -> str:
    """Put a PNG on the phone and return the MediaStore URI another app would share."""
    path = f"{IMAGE_DIR}/{name}"
    driver.push_file(path, base64.b64encode(data or solid_png()).decode())
    _shell(driver, "content", ["call", "--uri", "content://media", "--method", "scan_file", "--arg", path])
    rows = _shell(driver, "content", ["query", "--uri", IMAGES_COLLECTION, "--projection", "_id:_display_name"])
    for row in rows.splitlines():
        if f"_display_name={name}" in row and "_id=" in row:
            media_id = row.split("_id=", 1)[1].split(",", 1)[0].strip()
            return f"{IMAGES_COLLECTION}/{media_id}"
    raise RuntimeError(f"{name} was pushed to {IMAGE_DIR} but MediaStore does not list it")
