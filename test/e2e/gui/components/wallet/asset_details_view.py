import allure

import configs
import driver
from constants.wallet import (
    ASSET_DETAILS_INVALID_VALUES,
    WALLET_ACCOUNT_EXPECTED_ASSET_TITLES,
    WalletTokenSymbols,
)
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import wallet_names


class AssetDetailsView(QObject):
    def __init__(self):
        super().__init__(wallet_names.asset_details_view)

        self.asset_details_header = QObject(wallet_names.asset_details_header)
        self.tool_bar = QObject(wallet_names.asset_details_tool_bar)
        self.chart_panel = QObject(wallet_names.asset_details_chart_panel)
        self.chart = QObject(wallet_names.asset_details_chart_canvas)
        self._graph_loading = QObject(wallet_names.asset_details_graph_loading)
        self._chart_range_1y = Button(wallet_names.asset_details_chart_range_1y)

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

    def _graph_is_loaded(self) -> bool:
        if not self.chart.exists:
            return False
        try:
            if self._graph_loading.exists and str(self._graph_loading.object.active).lower() == 'true':
                return False
            return int(self.chart_panel.object.selectedStore.yearlyMaxTicks) > 0
        except (LookupError, RuntimeError, AttributeError, TypeError, ValueError):
            return False

    def _yearly_chart_range_selected(self) -> bool:
        try:
            return str(self.chart_panel.object.selectedTimeRange) == '1Y'
        except (LookupError, RuntimeError, AttributeError):
            return False

    @allure.step('Select 1Y chart time range')
    def select_yearly_chart_range(
        self,
        timeout_msec: int = configs.timeouts.WALLET_SYNC_TIMEOUT_MSEC,
    ) -> 'AssetDetailsView':
        self._chart_range_1y.wait_until_appears(timeout_msec)
        self._chart_range_1y.click()
        assert driver.waitFor(self._yearly_chart_range_selected, timeout_msec), (
            '1Y chart time range was not selected'
        )
        return self

    @allure.step('Wait until price graph is loaded with data')
    def wait_until_graph_has_data(
        self,
        timeout_msec: int = 60000,
    ) -> 'AssetDetailsView':
        assert driver.waitFor(self._graph_is_loaded, timeout_msec), 'Price graph has no data'
        return self

