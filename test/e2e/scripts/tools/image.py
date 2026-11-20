import logging
import time
import typing
from datetime import datetime

import allure
import cv2
import numpy as np
import pytesseract
from PIL import ImageGrab

import configs
import constants
import driver
from configs.system import get_platform
from scripts.tools.ocv import Ocv
from scripts.utils.system_path import SystemPath

LOG = logging.getLogger(__name__)


class Image:

    def __init__(self, object_name: dict):
        self.object_name = object_name
        self._view = None

    @property
    @allure.step('Get image view')
    def view(self) -> np.ndarray:
        return self._view

    @property
    @allure.step('Get image height')
    def height(self) -> int:
        return self.view.shape[0]

    @property
    @allure.step('Get image width')
    def width(self) -> int:
        return self.view.shape[1]

    @property
    @allure.step('Get image is grayscale')
    def is_grayscale(self) -> bool:
        return self.view.ndim == 2

    @allure.step('Set image in grayscale')
    def set_grayscale(self) -> 'Image':
        if not self.is_grayscale:
            self._view = cv2.cvtColor(self.view, cv2.COLOR_BGR2GRAY)
        return self

    @allure.step('Grab image view from object')
    def update_view(self):
        LOG.debug(f'Image view was grab from: {self.object_name}')
        rect = driver.bounds(driver.wait(self.object_name))
        img = ImageGrab.grab(
            bbox=(rect.x, rect.y, rect.x + rect.width, rect.y + rect.height),
            xdisplay=configs.system.DISPLAY if get_platform() == "Linux" else None
        )
        self._view = cv2.cvtColor(np.array(img), cv2.COLOR_BGR2RGB)

    @allure.step('Save image')
    def save(self, path: SystemPath, force: bool = False):
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists() and not force:
            raise FileExistsError(path)
        if self.view is None:
            self.update_view()
        cv2.imwrite(str(path), self.view)

    @allure.step('Compare images')
    def compare(
            self, expected: np.ndarray, threshold: float = 0.99) -> bool:
        if self.view is None:
            self.update_view()
        correlation = Ocv.compare_images(self.view, expected)
        result = correlation >= threshold
        LOG.info(f'Images equals on: {abs(round(correlation, 4) * 100)}%')

        if result:
            LOG.info(f'Screenshot comparison passed')
        else:
            configs.testpath.TEST_ARTIFACTS.mkdir(parents=True, exist_ok=True)
            diff = Ocv.draw_contours(self.view, expected)

            actual_fp = configs.testpath.TEST_ARTIFACTS / f'actual_image.png'
            expected_fp = configs.testpath.TEST_ARTIFACTS / f'expected_image.png'
            diff_fp = configs.testpath.TEST_ARTIFACTS / f'diff_image.png'

            self.save(actual_fp, force=True)
            cv2.imwrite(str(expected_fp), expected)
            cv2.imwrite(str(diff_fp), diff)

            allure.attach(name='actual', body=actual_fp.read_bytes(), attachment_type=allure.attachment_type.PNG)
            allure.attach(name='expected', body=expected_fp.read_bytes(), attachment_type=allure.attachment_type.PNG)
            allure.attach(name='diff', body=diff_fp.read_bytes(), attachment_type=allure.attachment_type.PNG)

            LOG.info(
                f"Screenshot comparison failed.\n"
                f"Actual, Diff and Expected screenshots are saved:\n"
                f"{configs.testpath.TEST_ARTIFACTS.relative_to(configs.testpath.ROOT)}.")
        return result

    @allure.step('Crop image')
    def crop(self, rect: driver.Rect):
        assert rect.x + rect.width < self.width
        assert rect.y + rect.height < self.height
        self._view = self.view[rect.y: (rect.y + rect.height), rect.x: (rect.x + rect.width)]

    @allure.step('Parse text on image')
    def to_string(self, custom_config: str):
        text: str = pytesseract.image_to_string(self.view, config=custom_config)
        LOG.debug(f'Text on image: {text}')
        return text

    @allure.step('Verify: Image contains text: {1}')
    def has_text(self, text: str, criteria: str, crop: driver.Rect = None) -> bool:
        self.update_view()
        if crop:
            self.crop(crop)

        # Search text on image converted in gray color
        self.set_grayscale()
        fp_gray = configs.testpath.TEST_ARTIFACTS / f'search_region_in_gray_color.png'
        self.save(fp_gray, force=True)
        if text.lower() in self.to_string(criteria).lower():
            allure.attach(name='search_region', body=fp_gray.read_bytes(), attachment_type=allure.attachment_type.PNG)
            return True

        # Search text on image with inverted color
        self._view = cv2.bitwise_not(self.view)
        fp_invert = configs.testpath.TEST_ARTIFACTS / f'search_region_in_inverted_color.png'
        self.save(fp_invert, force=True)
        if text.lower() in self.to_string(criteria).lower():
            allure.attach(name='search_region', body=fp_invert.read_bytes(), attachment_type=allure.attachment_type.PNG)
            return True
        return False

    @allure.step('Search color on image')
    def has_color(self, color: constants.Color, denoise: int = 10, crop: driver.Rect = None) -> bool:
        self.update_view()
        if crop:
            self.crop(crop)

        initial_view = configs.testpath.TEST_ARTIFACTS / f'{color.name}.png'
        self.save(initial_view)
        allure.attach(name='search_region', body=initial_view.read_bytes(), attachment_type=allure.attachment_type.PNG)

        contours = self._get_color_contours(color, denoise, apply=True)

        mask_view = configs.testpath.TEST_ARTIFACTS / f'{color.name}_mask.png'
        self.save(mask_view)
        allure.attach(name='contours', body=mask_view.read_bytes(), attachment_type=allure.attachment_type.PNG)

        self._view = None
        return len(contours) >= 1

    @allure.step('Apply contours with found color on image')
    def _get_color_contours(
            self,
            color: constants.Color,
            denoise: int = 10,
            apply: bool = False
    ) -> typing.List[driver.Rect]:
        if not self.is_grayscale:
            view = cv2.cvtColor(self.view, cv2.COLOR_BGR2HSV)
        else:
            view = self.view
        boundaries = constants.boundaries[color]

        if color == constants.Color.RED:
            mask = None
            for bond in boundaries:
                lower_range = np.array(bond[0])
                upper_range = np.array(bond[1])
                _mask = cv2.inRange(view, lower_range, upper_range)
                mask = _mask if mask is None else mask + _mask
        else:
            lower_range = np.array(boundaries[0])
            upper_range = np.array(boundaries[1])
            mask = cv2.inRange(view, lower_range, upper_range)

        contours = []
        _contours = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        _contours = _contours[0] if len(_contours) == 2 else _contours[1]
        for _contour in _contours:
            x, y, w, h = cv2.boundingRect(_contour)
            # To remove small artifacts, less than denoise variable value
            if w * h < denoise:
                continue
            contours.append(driver.Rect(x, y, w, h))

        if apply:
            self._view = cv2.bitwise_and(self.view, self.view, mask=mask)
            for contour in contours:
                cv2.rectangle(
                    self.view,
                    (contour.x, contour.y),
                    (contour.x + contour.width, contour.y + contour.height),
                    (36, 255, 12), 2)

        return contours


@allure.step('Compare images')
def compare(actual: Image,
            expected: typing.Union[str, SystemPath, Image],
            threshold: float = 0.99,
            timout_sec: int = 1
            ):
    expected_fp = None
    if isinstance(expected, str):
        expected_fp = configs.testpath.TEST_VP / configs.system.get_platform() / expected
        if not expected_fp.exists():
            expected_fp = configs.testpath.TEST_VP / expected
        expected = expected_fp
    if isinstance(expected, SystemPath):
        assert expected.exists(), f'File: {expected} not found'
        expected = cv2.imread(str(expected))
    else:
        expected = expected.view
    start = datetime.now()
    while not actual.compare(expected, threshold):
        time.sleep(1)
        if (datetime.now() - start).seconds > timout_sec:
            if configs.UPDATE_VP_ON_FAIL and expected_fp is not None:
                actual.save(expected_fp, force=True)
                LOG.warning(f'VP file updated: {expected_fp}')
                break
            else:
                raise AssertionError('Images comparison failed')
    LOG.info(f'Screenshot comparison passed')
