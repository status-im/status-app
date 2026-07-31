import logging

from gui.elements.object import QObject
from gui.objects_map import names

LOG = logging.getLogger(__name__)


class StatusModal(QObject):

    def __init__(self):
        super().__init__(names.statusModal)
        self.wait_until_enabled()


class StatusPopup(QObject):
    def __init__(self):
        super().__init__(names.basePopupItem)
        self.wait_until_enabled()
