"""Every session, including the peer-chat pool, runs on the device the run asked for."""

import pytest

from core.session_manager import SessionManager

pytestmark = pytest.mark.component


class FakeEnvConfig:
    def get_device(self, device_id=None):
        return device_id or "default_device"

    def find_devices_by_tags(self, tags):
        return [f"tagged:{','.join(tags)}"]


def manager(device_id=None, device_tags=None):
    instance = SessionManager.__new__(SessionManager)
    instance.env_config = FakeEnvConfig()
    instance.environment = "browserstack"
    instance._explicit_device_id = device_id
    instance._device_tags = device_tags or []
    instance._device_override = None
    return instance


def test_default_device_without_any_choice(monkeypatch):
    monkeypatch.delenv("TEST_DEVICE_ID", raising=False)
    assert manager()._select_device() == "default_device"


def test_test_device_id_applies_when_no_device_is_given(monkeypatch):
    monkeypatch.setenv("TEST_DEVICE_ID", "galaxy_tab_s10p_android_15")
    assert manager()._select_device() == "galaxy_tab_s10p_android_15"


def test_explicit_device_id_wins_over_test_device_id(monkeypatch):
    monkeypatch.setenv("TEST_DEVICE_ID", "galaxy_tab_s10p_android_15")
    assert manager(device_id="pixel_7_android_13")._select_device() == "pixel_7_android_13"


def test_test_device_id_wins_over_tags(monkeypatch):
    monkeypatch.setenv("TEST_DEVICE_ID", "pixel_7_android_13")
    assert manager(device_tags=["tablet"])._select_device() == "pixel_7_android_13"


def test_blank_test_device_id_is_ignored(monkeypatch):
    monkeypatch.setenv("TEST_DEVICE_ID", "  ")
    assert manager(device_tags=["tablet"])._select_device() == "tagged:tablet"
