#pragma once

// JSON array-of-strings codec for the status-go IPC argument list. The UI stub encodes
// with buildArgsJson; the service decodes with parseArgsJson. Must stay JNI-free so it
// can be unit tested on the host (see tests/).

#include <cstddef>
#include <cstdio>
#include <string>
#include <vector>

namespace statusgo_ipc {

inline void appendJsonEscaped(std::string& out, const char* s) {
  if (!s) return;
  for (const unsigned char* p = (const unsigned char*)s; *p; ++p) {
    const unsigned char c = *p;
    switch (c) {
      case '\\': out += "\\\\"; break;
      case '"': out += "\\\""; break;
      case '\b': out += "\\b"; break;
      case '\f': out += "\\f"; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      default:
        if (c < 0x20) {
          char buf[7];
          snprintf(buf, sizeof(buf), "\\u%04x", (unsigned)c);
          out += buf;
        } else {
          out.push_back((char)c);
        }
        break;
    }
  }
}

inline std::string buildArgsJson(const char** argv, size_t argc) {
  std::string out;
  out.reserve(64);
  out.push_back('[');
  for (size_t i = 0; i < argc; i++) {
    if (i) out.push_back(',');
    out.push_back('"');
    appendJsonEscaped(out, argv[i] ? argv[i] : "");
    out.push_back('"');
  }
  out.push_back(']');
  return out;
}

namespace detail {

inline int hexValue(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

inline bool readHex4(const char*& p, const char* end, unsigned& out) {
  if (end - p < 4) return false;
  out = 0;
  for (int i = 0; i < 4; ++i) {
    const int v = hexValue(p[i]);
    if (v < 0) return false;
    out = (out << 4) | (unsigned)v;
  }
  p += 4;
  return true;
}

inline void appendUtf8(std::string& out, unsigned cp) {
  if (cp < 0x80) {
    out.push_back((char)cp);
  } else if (cp < 0x800) {
    out.push_back((char)(0xC0 | (cp >> 6)));
    out.push_back((char)(0x80 | (cp & 0x3F)));
  } else if (cp < 0x10000) {
    out.push_back((char)(0xE0 | (cp >> 12)));
    out.push_back((char)(0x80 | ((cp >> 6) & 0x3F)));
    out.push_back((char)(0x80 | (cp & 0x3F)));
  } else {
    out.push_back((char)(0xF0 | (cp >> 18)));
    out.push_back((char)(0x80 | ((cp >> 12) & 0x3F)));
    out.push_back((char)(0x80 | ((cp >> 6) & 0x3F)));
    out.push_back((char)(0x80 | (cp & 0x3F)));
  }
}

// Decodes the escape after "\u"; unpaired surrogates become U+FFFD.
inline bool readUnicodeEscape(const char*& p, const char* end, std::string& out) {
  unsigned cp = 0;
  if (!readHex4(p, end, cp)) return false;
  if (cp >= 0xD800 && cp <= 0xDBFF) {
    const char* q = p;
    unsigned lo = 0;
    if (end - q >= 2 && q[0] == '\\' && q[1] == 'u') {
      q += 2;
      if (readHex4(q, end, lo) && lo >= 0xDC00 && lo <= 0xDFFF) {
        p = q;
        appendUtf8(out, 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00));
        return true;
      }
    }
    cp = 0xFFFD;
  } else if (cp >= 0xDC00 && cp <= 0xDFFF) {
    cp = 0xFFFD;
  }
  appendUtf8(out, cp);
  return true;
}

inline void skipWhitespace(const char*& p, const char* end) {
  while (p < end && (*p == ' ' || *p == '\n' || *p == '\t' || *p == '\r')) ++p;
}

inline bool parseJsonString(const char*& p, const char* end, std::string& out) {
  if (p >= end || *p != '"') return false;
  ++p;
  while (p < end) {
    const char* run = p;
    while (p < end && *p != '"' && *p != '\\') ++p;
    out.append(run, p - run);
    if (p >= end) return false;
    if (*p++ == '"') return true;
    if (p >= end) return false;
    const char e = *p++;
    switch (e) {
      case '"': out.push_back('"'); break;
      case '\\': out.push_back('\\'); break;
      case '/': out.push_back('/'); break;
      case 'b': out.push_back('\b'); break;
      case 'f': out.push_back('\f'); break;
      case 'n': out.push_back('\n'); break;
      case 'r': out.push_back('\r'); break;
      case 't': out.push_back('\t'); break;
      case 'u':
        if (!readUnicodeEscape(p, end, out)) return false;
        break;
      default:
        out.push_back(e);
        break;
    }
  }
  return false;
}

} // namespace detail

// Parses at most len bytes; the input need not be NUL-terminated.
inline std::vector<std::string> parseArgsJson(const char* data, size_t len) {
  std::vector<std::string> out;
  if (!data) return out;
  const char* p = data;
  const char* end = data + len;
  detail::skipWhitespace(p, end);
  if (p >= end || *p != '[') return out;
  ++p;
  while (p < end) {
    detail::skipWhitespace(p, end);
    if (p >= end || *p == ']') break;
    std::string s;
    if (!detail::parseJsonString(p, end, s)) break;
    out.push_back(std::move(s));
    detail::skipWhitespace(p, end);
    if (p < end && *p == ',') { ++p; continue; }
    break;
  }
  return out;
}

inline std::vector<std::string> parseArgsJson(const std::string& json) {
  return parseArgsJson(json.data(), json.size());
}

} // namespace statusgo_ipc
