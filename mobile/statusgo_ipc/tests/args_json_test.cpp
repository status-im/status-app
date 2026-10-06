// Host test for the IPC argument codec: make -C mobile ipc-host-tests
#include "../args_json.h"

#include <cstdio>
#include <string>
#include <vector>

using namespace statusgo_ipc;

static int g_failures = 0;

#define CHECK_EQ(actual, expected)                                                   \
  do {                                                                               \
    if (!((actual) == (expected))) {                                                 \
      std::fprintf(stderr, "%s:%d: CHECK_EQ(%s, %s) failed\n", __FILE__, __LINE__, \
                   #actual, #expected);                                              \
      ++g_failures;                                                                  \
    }                                                                                \
  } while (0)

static std::vector<std::string> roundTrip(const std::vector<std::string>& args) {
  std::vector<const char*> argv;
  for (const auto& a : args) argv.push_back(a.c_str());
  return parseArgsJson(buildArgsJson(argv.data(), argv.size()));
}

static void testControlCharactersRoundTrip() {
  std::string all;
  for (int c = 1; c < 0x20; ++c) all.push_back((char)c);
  all += "\"\\/";
  const auto out = roundTrip({all});
  CHECK_EQ(out.size(), 1u);
  if (!out.empty()) CHECK_EQ(out[0], all);
}

static void testNonAsciiRoundTrip() {
  const std::string s = "caf\xc3\xa9 \xe4\xb8\xad \xf0\x9f\x98\x80";
  const auto out = roundTrip({s, "", "plain"});
  CHECK_EQ(out.size(), 3u);
  if (out.size() == 3) {
    CHECK_EQ(out[0], s);
    CHECK_EQ(out[1], std::string());
    CHECK_EQ(out[2], std::string("plain"));
  }
}

// Java's JSONObject.quote and other encoders emit \uXXXX for BMP and surrogate pairs.
static void testUnicodeEscapesDecodeToUtf8() {
  const auto out = parseArgsJson(
      "[\"\\u00e9\", \"\\u4E2D\", \"\\ud83d\\ude00\", \"\\u2028\", \"a\\u0000b\"]");
  CHECK_EQ(out.size(), 5u);
  if (out.size() == 5) {
    CHECK_EQ(out[0], std::string("\xc3\xa9"));
    CHECK_EQ(out[1], std::string("\xe4\xb8\xad"));
    CHECK_EQ(out[2], std::string("\xf0\x9f\x98\x80"));
    CHECK_EQ(out[3], std::string("\xe2\x80\xa8"));
    CHECK_EQ(out[4], std::string("a\0b", 3));
  }
}

static void testLargeArgumentDeliveredIntact() {
  std::string big;
  big.reserve(1100 * 1024);
  while (big.size() < 1100 * 1024) {
    for (int c = 1; c < 256; ++c) big.push_back((char)c);
  }
  const auto out = roundTrip({"method", big});
  CHECK_EQ(out.size(), 2u);
  if (out.size() == 2) CHECK_EQ(out[1] == big, true);
}

static void testMalformedInputStopsWithinBounds() {
  const std::string inputs[] = {"[\"abc", "[\"a\\", "[\"\\u12", "[\"\\uZZZZ\"]", "[\"ok\",", "", "x"};
  for (const auto& in : inputs) {
    std::vector<char> exact(in.begin(), in.end());
    parseArgsJson(exact.data(), exact.size());
  }
  const auto partial = parseArgsJson(std::string("[\"ok\", \"\\ud83d\"]"));
  CHECK_EQ(partial.size(), 2u);
  if (partial.size() == 2) CHECK_EQ(partial[1], std::string("\xef\xbf\xbd"));
}

int main() {
  testControlCharactersRoundTrip();
  testNonAsciiRoundTrip();
  testUnicodeEscapesDecodeToUtf8();
  testLargeArgumentDeliveredIntact();
  testMalformedInputStopsWithinBounds();
  if (g_failures) {
    std::fprintf(stderr, "args_json_test: %d failure(s)\n", g_failures);
    return 1;
  }
  std::printf("args_json_test: OK\n");
  return 0;
}
