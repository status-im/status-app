"""Pages package for tablet E2E tests."""

from .base_page import BasePage
from .app import App
from .onboarding import (
    HomePage,
    WelcomePage,
    CreateProfilePage,
    PasswordPage,
    SplashScreen,
    WelcomeBackPage,
)

__all__ = [
    "BasePage",
    "HomePage",
    "App",
    "WelcomePage",
    "CreateProfilePage",
    "PasswordPage",
    "SplashScreen",
    "WelcomeBackPage",
]
