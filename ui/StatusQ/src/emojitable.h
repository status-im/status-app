#pragma once

#include <cstdint>

// The emoji catalogue as read-only data, generated into emojitable_data.cpp by
// tools/emoji/build-table.py. Refs are offsets rather than pointers so the table
// needs no relocations and stays in pages the OS can drop.
namespace EmojiTable {

// Offset into `strings`, a pool of NUL-terminated UTF-8 strings.
using StringRef = std::uint32_t;
// Offset into `lists`: a count followed by that many StringRefs.
using ListRef = std::uint32_t;

struct Entry
{
    StringRef emoji;
    StringRef unicode;
    StringRef canonical; // spelling-insensitive form of `unicode`, see StatusEmojiModel
    StringRef name;
    StringRef shortname;
    ListRef aliases;
    ListRef aliasesAscii;
    ListRef keywords;
    std::uint16_t order;
    std::uint8_t category; // index into StatusEmojiModel::categories(), "recent" not counted
    std::uint8_t skin;     // 0 no skins, 1 base of toned variants, 2 + i the i-th tone
};

struct AsciiAlias
{
    StringRef alias;
    std::uint16_t entry;
};

extern const unsigned char strings[];
extern const std::uint32_t lists[];

extern const std::uint16_t entryCount;
extern const Entry entries[];

// Entry indices sorted by that field, bytewise.
extern const std::uint16_t byUnicode[];
extern const std::uint16_t byCanonical[];
extern const std::uint16_t byShortname[];

// Sorted bytewise; the first entry listing an emoticon owns it.
extern const std::uint16_t asciiAliasCount;
extern const AsciiAlias asciiAliases[];
extern const std::uint16_t maxAsciiAliasLength;

// First entry of each category; flags are the last block.
extern const std::uint16_t categoryStart[];
extern const std::uint16_t firstFlagEntry;

} // namespace EmojiTable
