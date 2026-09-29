"""TEMPORARY: validate CI issue reporting; remove before merging."""

import pytest

pytestmark = pytest.mark.critical


@pytest.mark.parametrize("case", ["first", "second", "third"])
def test_intentional_shared_failure(case):
    pytest.fail("INTENTIONAL CI REPORTING CHECK v2: updated shared failure", pytrace=False)


@pytest.fixture
def intentional_setup_failure():
    raise RuntimeError("INTENTIONAL CI REPORTING CHECK v2: updated setup error")


def test_intentional_setup_error(intentional_setup_failure):
    pass
