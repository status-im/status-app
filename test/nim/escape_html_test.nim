## Unit tests for the pure-Nim escape_html implementation.
## No Qt required — tests the character-replacement logic only.

import unittest
import app_service/common/utils

suite "escape_html":

  test "escapes ampersand, re-escaping existing entities (matches Qt)":
    check escape_html("a & b") == "a &amp; b"
    # Faithful to QString::toHtmlEscaped: the & of an existing entity is itself escaped.
    check escape_html("&amp;") == "&amp;amp;"

  test "escapes less-than and greater-than":
    check escape_html("<tag>") == "&lt;tag&gt;"

  test "escapes double-quote":
    check escape_html("say \"hi\"") == "say &quot;hi&quot;"

  test "apostrophe is left unchanged (matches Qt: ' is not escaped)":
    check escape_html("it's a \"test\"") == "it's a &quot;test&quot;"

  test "combined all four special chars":
    check escape_html("a & b < c > d \" e") == "a &amp; b &lt; c &gt; d &quot; e"

  test "plain string is unchanged":
    check escape_html("hello world") == "hello world"

  test "empty string":
    check escape_html("") == ""
