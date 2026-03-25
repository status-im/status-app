"""Onboarding page objects package."""

from .welcome_page import WelcomePage
from .create_profile_page import CreateProfilePage
from .password_page import PasswordPage
from .loading_page import SplashScreen
from .home_page import HomePage
from .seed_phrase_input_page import SeedPhraseInputPage
from .welcome_back_page import WelcomeBackPage
from .biometrics_page import BiometricsPage
from .push_notifications_page import PushNotificationsPage

__all__ = [
    "WelcomePage",
    "CreateProfilePage",
    "PasswordPage",
    "SplashScreen",
    "HomePage",
    "SeedPhraseInputPage",
    "WelcomeBackPage",
    "BiometricsPage",
    "PushNotificationsPage",
]
