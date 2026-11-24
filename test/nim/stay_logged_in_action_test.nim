## Unit tests for mapping the login data's optional "stayLoggedIn" choice to the
## post-login action. Disable deletes the saved credential, so only an explicit JSON
## `false` may produce it; anything malformed must follow the stored preference.

import unittest
import std/json

import app/modules/onboarding/post_onboarding/save_stay_logged_in_task

suite "stayLoggedInActionFromLoginData":

  test "missing key follows the stored preference":
    check stayLoggedInActionFromLoginData(%*{"password": "x"}) ==
      StayLoggedInAction.FollowStored

  test "true enables":
    check stayLoggedInActionFromLoginData(%*{"stayLoggedIn": true}) ==
      StayLoggedInAction.Enable

  test "false disables":
    check stayLoggedInActionFromLoginData(%*{"stayLoggedIn": false}) ==
      StayLoggedInAction.Disable

  test "null or a non-bool value follows the stored preference":
    check stayLoggedInActionFromLoginData(%*{"stayLoggedIn": nil}) ==
      StayLoggedInAction.FollowStored
    check stayLoggedInActionFromLoginData(%*{"stayLoggedIn": "false"}) ==
      StayLoggedInAction.FollowStored
    check stayLoggedInActionFromLoginData(%*{"stayLoggedIn": 0}) ==
      StayLoggedInAction.FollowStored
