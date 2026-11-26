import logging
import time
import typing

import allure

import configs
import driver
from gui.elements.object import QObject

LOG = logging.getLogger(__name__)


class List(QObject):

    @property
    @allure.step('Get list items {0}')
    def items(self):
        return [self.object.itemAtIndex(index) for index in range(self.object.count)]

    @allure.step('Get values of list items {0}')
    def get_values(self, attr_name: str) -> typing.List[str]:
        values = []
        for index in range(self.object.count):
            value = str(getattr(self.object.itemAtIndex(index), attr_name, ''))
            if value:
                values.append(value)
        return values

    @allure.step('Select item {1} in {0}')
    def select(self, value: str, attr_name: str):
        driver.click(self.wait_for_item(value, attr_name))
        LOG.info(f'{self}: {value} selected')

    @allure.step('Wait for item {1} in {0} with attribute {2}')
    def wait_for_item(self, value: str, attr_name: str, timeout_sec: int = configs.timeouts.UI_LOAD_TIMEOUT_SEC):
        started_at = time.monotonic()
        values = []
        while True:
            for index in range(self.object.count):
                cur_value = str(getattr(self.object.itemAtIndex(index), attr_name, ''))
                if cur_value == value:
                    LOG.info(f'{self}: "{value}" for attribute "{attr_name}" appeared')
                    return self.object.itemAtIndex(index)
                values.append(cur_value)
            time.sleep(1)
            if time.monotonic() - started_at > timeout_sec:
                raise RuntimeError(f'value not found in list: {values}')
