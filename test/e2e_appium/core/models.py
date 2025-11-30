from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


DEFAULT_USER_PASSWORD = "StatusPassword123!"

@dataclass
class TestUser:
    display_name: str
    password: str = DEFAULT_USER_PASSWORD
    seed_phrase: Optional[List[str]] = None
    wallet_address: Optional[str] = None
    source: str = "created"

    __test__ = False  # Prevent pytest from treating this helper as a test class

    def to_dict(self) -> Dict[str, Any]:
        return {
            "display_name": self.display_name,
            "password": self.password,
            "seed_phrase": self.seed_phrase,
            "wallet_address": self.wallet_address,
            "source": self.source,
        }

    @classmethod
    def from_onboarding_result(
        cls,
        payload: Dict[str, Any],
        config,
    ) -> "TestUser":
        seed_phrase = payload.get("seed_phrase") or getattr(config, "seed_phrase", None) or []
        if isinstance(seed_phrase, str):
            seed_phrase = seed_phrase.split()

        profile = payload.get("profile", {}) or {}

        return cls(
            display_name=payload.get("display_name") or profile.get("display_name", "Unknown"),
            password=payload.get("password") or getattr(config, "custom_password", None) or DEFAULT_USER_PASSWORD,
            seed_phrase=seed_phrase,
            wallet_address=payload.get("wallet_address"),
            source="onboarded",
        )


@dataclass
class TestAppState:
    is_home_loaded: bool = False
    current_screen: str = "unknown"
    requires_authentication: bool = False
    has_existing_profiles: bool = False

    __test__ = False


@dataclass
class TestConfiguration:
    environment: str = "browserstack"
    profile_method: str = "password"
    display_name: str = "TestUser"
    validate_steps: bool = True
    take_screenshots: bool = False
    custom_config: Dict[str, Any] = field(default_factory=dict)
    device_override: Optional[Dict[str, Any]] = None
    device_id: Optional[str] = None
    device_tags: List[str] = field(default_factory=list)

    __test__ = False

    @classmethod
    def from_pytest_marker(cls, request, marker_name: str) -> "TestConfiguration":
        config = cls()
        for marker in request.node.iter_markers():
            if marker.name == marker_name:
                for key, value in marker.kwargs.items():
                    if hasattr(config, key):
                        setattr(config, key, value)
                    else:
                        config.custom_config[key] = value
                break
        return config
