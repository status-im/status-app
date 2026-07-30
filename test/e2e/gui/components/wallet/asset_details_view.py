import typing

import allure

import configs
import driver
from constants.wallet import (
    ASSET_DETAILS_INVALID_VALUES,
    WALLET_ACCOUNT_EXPECTED_ASSET_TITLES,
    WalletTokenSymbols,
)
from driver.objects_access import walk_children
from gui.elements.object import QObject
from gui.objects_map import wallet_names


class AssetDetailsView(QObject):
    def __init__(self):
        super().__init__(wallet_names.asset_details_view)

        self.asset_details_header = QObject(wallet_names.asset_details_header)
        self.tool_bar = QObject(wallet_names.asset_details_tool_bar)
        self.chart_panel = QObject(wallet_names.asset_details_chart_panel)
        self.chart = QObject(wallet_names.asset_details_chart_canvas)

    def _header_text(self, attr: str) -> str:
        return str(getattr(self.asset_details_header.object, attr, ''))

    def _header_is_loaded(self) -> bool:
        if getattr(self.asset_details_header.object, 'isLoading', True):
            return False
        return self._header_text('primaryText') in WALLET_ACCOUNT_EXPECTED_ASSET_TITLES

    @allure.step('Wait until asset details header is loaded')
    def wait_until_header_loaded(
        self,
        timeout_msec: int = configs.timeouts.WALLET_SYNC_TIMEOUT_MSEC,
    ) -> 'AssetDetailsView':
        assert driver.waitFor(lambda: self._header_is_loaded(), timeout_msec), (
            f'Asset details header is still loading, title={self._header_text("primaryText")!r}'
        )
        return self

    @allure.step('Verify asset balances are displayed in header')
    def verify_balance_displayed(self) -> 'AssetDetailsView':
        for label, attr in (('Crypto', 'secondaryText'), ('Fiat', 'tertiaryText')):
            value = self._header_text(attr)
            assert value not in ASSET_DETAILS_INVALID_VALUES, (
                f'{label} balance is not displayed: {value!r}'
            )
        return self

    @property
    @allure.step('Get token symbol from header')
    def token_symbol(self) -> str:
        return WalletTokenSymbols.from_title(self._header_text('primaryText')).value

    @property
    @allure.step('Get button title')
    def back_button_title(self) -> str:
        return str(self.tool_bar.object.backButtonName)

    @property
    @allure.step('Check price graph is visible')
    def graph_is_visible(self) -> bool:
        return self.chart_panel.is_visible and self.chart.is_visible

    @staticmethod
    def _qml_sequence_length(value: typing.Any) -> int:
        if value is None:
            return 0
        if isinstance(value, (list, tuple, str)):
            return len(value)
        length = getattr(value, 'length', None)
        if length is not None:
            try:
                return int(length)
            except (TypeError, ValueError):
                pass
        count = 0
        while True:
            try:
                value[count]
                count += 1
            except (IndexError, LookupError, RuntimeError, TypeError, AttributeError):
                break
        return count

    @staticmethod
    def _get_dataset_data(datasets: typing.Any) -> typing.Any:
        if AssetDetailsView._qml_sequence_length(datasets) == 0:
            return None
        try:
            dataset = datasets[0]
        except (IndexError, LookupError, TypeError):
            return None
        data = getattr(dataset, 'data', None)
        if data is None and isinstance(dataset, dict):
            data = dataset.get('data')
        return data

    def _get_chart(self):
        try:
            chart = getattr(self.chart_panel.object, 'chart', None)
            if chart is not None:
                return chart
        except (LookupError, RuntimeError, AttributeError):
            pass
        return self.chart.object

    @staticmethod
    def _chart_has_data(chart) -> bool:
        labels = getattr(chart, 'labels', None)
        datasets = getattr(chart, 'datasets', None)
        data = AssetDetailsView._get_dataset_data(datasets)
        return (
            AssetDetailsView._qml_sequence_length(labels) > 0
            and AssetDetailsView._qml_sequence_length(data) > 0
        )

    def _is_graph_loading(self) -> bool:
        try:
            panel = self.chart_panel.object
        except (LookupError, RuntimeError):
            return True
        for child in walk_children(panel):
            try:
                if getattr(child, 'active', False):
                    return True
            except (RuntimeError, AttributeError):
                continue
        return False

    def _graph_is_loaded(self) -> bool:
        if not self.graph_is_visible:
            return False
        if self._chart_has_data(self._get_chart()):
            return True
        # Squish often cannot read ChartCanvas labels/datasets; use the app's loading overlay instead.
        return not self._is_graph_loading()

    @allure.step('Wait until price graph is loaded with data')
    def wait_until_graph_has_data(
        self,
        timeout_msec: int = 60000,
    ) -> 'AssetDetailsView':
        assert driver.waitFor(lambda: self.graph_is_visible, timeout_msec), \
            'Price graph is not visible'

        assert driver.waitFor(
            lambda: self._graph_is_loaded(),
            timeout_msec,
        ), 'Price graph has no data'

        return self
