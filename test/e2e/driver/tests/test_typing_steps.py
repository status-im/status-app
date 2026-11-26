from driver.actions import key_of, typing_steps


def test_text_and_a_key_are_separate_steps():
    assert typing_steps("ab<Return>") == [("text", "ab"), ("key", "Return")]


def test_a_shortcut_keeps_its_modifiers():
    assert typing_steps("<Ctrl+A>") == [("key", "Ctrl+A")]
    assert typing_steps("<Ctrl+Shift+Tab>") == [("key", "Ctrl+Shift+Tab")]


def test_short_key_names_become_qt_key_names():
    assert key_of("PageDown") == "PgDown"
    assert key_of("Esc") == "Escape"


def test_angle_brackets_around_ordinary_text_are_typed_as_text():
    # Random passwords in the tests contain such text.
    assert typing_steps("a<7>b") == [("text", "a<7>b")]
    assert typing_steps("x<^>y<Returns>") == [("text", "x<^>y<Returns>")]


def test_an_unknown_modifier_makes_the_token_text():
    assert typing_steps("<a+b>") == [("text", "<a+b>")]


def test_an_unclosed_bracket_is_text():
    assert typing_steps("<Return") == [("text", "<Return")]
    assert typing_steps("<Returnx") == [("text", "<Returnx")]
    assert typing_steps("<<Tab>") == [("text", "<"), ("key", "Tab")]
