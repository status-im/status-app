##
##  QR Code generator library (C)
##
##  Copyright (c) Project Nayuki. (MIT License)
##  https://www.nayuki.io/page/qr-code-generator-library
##
##  Permission is hereby granted, free of charge, to any person obtaining a copy of
##  this software and associated documentation files (the "Software"), to deal in
##  the Software without restriction, including without limitation the rights to
##  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
##  the Software, and to permit persons to whom the Software is furnished to do so,
##  subject to the following conditions:
##  - The above copyright notice and this permission notice shall be included in
##    all copies or substantial portions of the Software.
##  - The Software is provided "as is", without warranty of any kind, express or
##    implied, including but not limited to the warranties of merchantability,
##    fitness for a particular purpose and noninfringement. In no event shall the
##    authors or copyright holders be liable for any claim, damages or other
##    liability, whether in an action of contract, tort or otherwise, arising from,
##    out of or in connection with the Software or the use or other dealings in the
##    Software.
##

##
##  This library creates QR Code symbols, which is a type of two-dimension barcode.
##  Invented by Denso Wave and described in the ISO/IEC 18004 standard.
##  A QR Code structure is an immutable square grid of black and white cells.
##  The library provides functions to create a QR Code from text or binary data.
##  The library covers the QR Code Model 2 specification, supporting all versions (sizes)
##  from 1 to 40, all 4 error correction levels, and 4 character encoding modes.
##
##  Ways to create a QR Code object:
##  - High level: Take the payload data and call qrcodegen_encodeText() or qrcodegen_encodeBinary().
##  - Low level: Custom-make the list of segments and call
##    qrcodegen_encodeSegments() or qrcodegen_encodeSegmentsAdvanced().
##  (Note that all ways require supplying the desired error correction level and various byte buffers.)
##
## ---- Enum and struct types----
##
##  The error correction level in a QR Code symbol.
##

type
  qrcodegen_Ecc* = enum ##  Must be declared in ascending order of error protection
                     ##  so that an internal qrcodegen function works properly
    qrcodegen_Ecc_LOW = 0,      ##  The QR Code can tolerate about  7% erroneous codewords
    qrcodegen_Ecc_MEDIUM,     ##  The QR Code can tolerate about 15% erroneous codewords
    qrcodegen_Ecc_QUARTILE,   ##  The QR Code can tolerate about 25% erroneous codewords
    qrcodegen_Ecc_HIGH        ##  The QR Code can tolerate about 30% erroneous codewords


##
##  The mask pattern used in a QR Code symbol.
##

type
  qrcodegen_Mask* = enum        ##  A special value to tell the QR Code encoder to
                      ##  automatically select an appropriate mask pattern
    qrcodegen_Mask_AUTO = -1,   ##  The eight actual mask patterns
    qrcodegen_Mask_0 = 0, qrcodegen_Mask_1, qrcodegen_Mask_2, qrcodegen_Mask_3,
    qrcodegen_Mask_4, qrcodegen_Mask_5, qrcodegen_Mask_6, qrcodegen_Mask_7


##
##  Describes how a segment's data bits are interpreted.
##

type
  qrcodegen_Mode* = enum
    qrcodegen_Mode_NUMERIC = 0x00000001, qrcodegen_Mode_ALPHANUMERIC = 0x00000002,
    qrcodegen_Mode_BYTE = 0x00000004, qrcodegen_Mode_ECI = 0x00000007,
    qrcodegen_Mode_KANJI = 0x00000008


##
##  A segment of character/binary/control data in a QR Code symbol.
##  The mid-level way to create a segment is to take the payload data
##  and call a factory function such as qrcodegen_makeNumeric().
##  The low-level way to create a segment is to custom-make the bit buffer
##  and initialize a qrcodegen_Segment struct with appropriate values.
##  Even in the most favorable conditions, a QR Code can only hold 7089 characters of data.
##  Any segment longer than this is meaningless for the purpose of generating QR Codes.
##  Moreover, the maximum allowed bit length is 32767 because
##  the largest QR Code (version 40) has 31329 modules.
##

type
  qrcodegen_Segment* {.bycopy.} = object
    mode*: qrcodegen_Mode      ##  The mode indicator of this segment.
    ##  The length of this segment's unencoded data. Measured in characters for
    ##  numeric/alphanumeric/kanji mode, bytes for byte mode, and 0 for ECI mode.
    ##  Always zero or positive. Not the same as the data's bit length.
    numChars*: cint ##  The data bits of this segment, packed in bitwise big endian.
                  ##  Can be null if the bit length is zero.
    data*: ptr uint8 ##  The number of valid data bits used in the buffer. Requires
                    ##  0 <= bitLength <= 32767, and bitLength <= (capacity of data array) * 8.
                    ##  The character count (numChars) must agree with the mode and the bit buffer length.
    bitLength*: cint


## ---- Macro constants and functions ----

const
  qrcodegen_VERSION_MIN* = 1
  qrcodegen_VERSION_MAX* = 40

##  Calculates the number of bytes needed to store any QR Code up to and including the given version number,
##  as a compile-time constant. For example, 'uint8 buffer[qrcodegen_BUFFER_LEN_FOR_VERSION(25)];'
##  can store any single QR Code from version 1 to 25 (inclusive). The result fits in an int (or int16).
##  Requires qrcodegen_VERSION_MIN <= n <= qrcodegen_VERSION_MAX.

template qrcodegen_BUFFER_LEN_FOR_VERSION*(n: untyped): untyped =
  ((((n) * 4 + 17) * ((n) * 4 + 17) + 7) div 8 + 1)

##  The worst-case number of bytes needed to store one QR Code, up to and including
##  version 40. This value equals 3918, which is just under 4 kilobytes.
##  Use this more convenient value to avoid calculating tighter memory bounds for buffers.

const
  qrcodegen_BUFFER_LEN_MAX* = qrcodegen_BUFFER_LEN_FOR_VERSION(
      qrcodegen_VERSION_MAX)

## ---- Functions (high level) to generate QR Codes ----
##
##  Encodes the given text string to a QR Code, returning true if encoding succeeded.
##  If the data is too long to fit in any version in the given range
##  at the given ECC level, then false is returned.
##  - The input text must be encoded in UTF-8 and contain no NULs.
##  - The variables ecl and mask must correspond to enum constant values.
##  - Requires 1 <= minVersion <= maxVersion <= 40.
##  - The arrays tempBuffer and qrcode must each have a length
##    of at least qrcodegen_BUFFER_LEN_FOR_VERSION(maxVersion).
##  - After the function returns, tempBuffer contains no useful data.
##  - If successful, the resulting QR Code may use numeric,
##    alphanumeric, or byte mode to encode the text.
##  - In the most optimistic case, a QR Code at version 40 with low ECC
##    can hold any UTF-8 string up to 2953 bytes, or any alphanumeric string
##    up to 4296 characters, or any digit string up to 7089 characters.
##    These numbers represent the hard upper limit of the QR Code standard.
##  - Please consult the QR Code specification for information on
##    data capacities per version, ECC level, and text encoding mode.
##

proc qrcodegen_encodeText*(text: cstring; tempBuffer: ptr uint8;
                          qrcode: ptr uint8; ecl: qrcodegen_Ecc; minVersion: cint;
                          maxVersion: cint; mask: qrcodegen_Mask; boostEcl: bool): bool {.importc: "qrcodegen_encodeText".}

#proc qrcodegen_makeEci*(assignVal: clong; buf: ptr uint8): qrcodegen_Segment
## ---- Functions to extract raw data from QR Codes ----
##
##  Returns the side length of the given QR Code, assuming that encoding succeeded.
##  The result is in the range [21, 177]. Note that the length of the array buffer
##  is related to the side length - every 'uint8 qrcode[]' must have length at least
##  qrcodegen_BUFFER_LEN_FOR_VERSION(version), which equals ceil(size^2 / 8 + 1).
##

proc qrcodegen_getSize*(qrcode: ptr uint8): cint {.importc: "qrcodegen_getSize".}
##
##  Returns the color of the module (pixel) at the given coordinates, which is false
##  for white or true for black. The top left corner has the coordinates (x=0, y=0).
##  If the given coordinates are out of bounds, then false (white) is returned.
##

proc qrcodegen_getModule*(qrcode: ptr uint8; x: cint; y: cint): bool {.importc: "qrcodegen_getModule".}
