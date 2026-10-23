import pathlib

import allure

from gui.elements.object import QObject
from gui.objects_map import names
from scripts.utils.system_path import SystemPath


class QRCodeScannerPopup(QObject):

    def __init__(self):
        super().__init__(names.qrCodeScanner)

    @allure.step('Upload a QR image')
    def upload_image(self, fp: SystemPath) -> None:
        file_uri = pathlib.Path(str(fp)).resolve().as_uri()
        self.object.scanImageFile(file_uri)
