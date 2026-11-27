import struct
import subprocess
import zlib
from pathlib import Path

import allure

import configs

# Smallest files each viewer accepts; the tests check the Tab, not the rendering.
_PDF = (
    b'%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
    b'2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
    b'3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\n'
    b'trailer<</Root 1 0 R>>\n%%EOF\n'
)


def _png() -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    header = struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0)
    pixel = zlib.compress(b'\x00\xff\x00\x00')
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', pixel) + chunk(b'IEND', b'')


_PNG = _png()
SAMPLES = {
    'pdf': _PDF,
    'png': _PNG,
    'txt': 'Open with e2e: plain text\n'.encode(),
    'json': b'{"openWith": "e2e"}\n',
    'mp3': b'ID3\x03\x00\x00\x00\x00\x00\x00' + b'\x00' * 64,
    'webm': bytes.fromhex('1a45dfa3') + b'\x00' * 64,
    'zip': b'PK\x05\x06' + b'\x00' * 18,
}


def sample_file(directory: Path, extension: str, stem: str = 'open-with-sample') -> Path:
    path = directory / f'{stem}.{extension}'
    path.write_bytes(SAMPLES[extension])
    return path


def app_bundle() -> Path:
    """The .app the AUT runs from: macOS hands a file to an app by its bundle."""
    for candidate in [Path(configs.AUT_PATH), *Path(configs.AUT_PATH).parents]:
        if candidate.suffix == '.app':
            return candidate
    raise RuntimeError(f'AUT_PATH is not inside an .app bundle: {configs.AUT_PATH}')


@allure.step('Open {path} with Status, as Finder does')
def open_with_status(path: Path) -> None:
    subprocess.run(['open', '-a', str(app_bundle()), str(path)], check=True, timeout=30)
