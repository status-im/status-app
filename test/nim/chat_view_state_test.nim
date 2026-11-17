import unittest
import nimqml

import app/modules/main/chat_section/view_state
import app/modules/main/chat_section/chat_content/messages/reading_positions

suite "chat section view state":
  test "the shown panel is kept":
    let state = newViewState()
    check state.getShownPanel() == 0

    state.setShownPanel(1)
    check state.getShownPanel() == 1

suite "reading positions":
  test "a chat without a record has none":
    let positions = newReadingPositions()
    check positions.getRecord("") == ""

  test "each thread keeps its own record":
    let positions = newReadingPositions()
    positions.setRecord("", """{"atBottom":true}""")
    positions.setRecord("thread-1", """{"key":"m1","offset":12}""")

    check positions.getRecord("") == """{"atBottom":true}"""
    check positions.getRecord("thread-1") == """{"key":"m1","offset":12}"""

  test "a record is replaced, and cleared by an empty one":
    let positions = newReadingPositions()
    positions.setRecord("", """{"key":"m1","offset":12}""")
    positions.setRecord("", """{"key":"m2","offset":0}""")
    check positions.getRecord("") == """{"key":"m2","offset":0}"""

    positions.setRecord("", "")
    check positions.getRecord("") == ""
