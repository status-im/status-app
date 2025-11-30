"""Onboarding page objects package."""

from .welcome_page import WelcomePage
from .analytics_page import AnalyticsPage
from .create_profile_page import CreateProfilePage
from .password_page import PasswordPage
from .loading_page import SplashScreen
from .home_page import HomePage
from .seed_phrase_input_page import SeedPhraseInputPage
from .welcome_back_page import WelcomeBackPage
from .biometrics_page import BiometricsPage

__all__ = [
    "WelcomePage",
    "AnalyticsPage",
    "CreateProfilePage",
    "PasswordPage",
    "SplashScreen",
    "HomePage",
    "SeedPhraseInputPage",
    "WelcomeBackPage",
    "BiometricsPage",
]
