# cmake -P script: runs the Nim compiler for the Storybook aggregate library and
# writes a Make-style depfile listing every input, so the custom command in
# NimLibs.cmake rebuilds when any of them changes:
#   - every Nim module the build imported or included (from a second,
#     front-end-only `--genScript:on` pass, which writes `<project>.deps`
#     but compiles nothing),
#   - the C/C++ sources those modules `{.compile.}` and their sibling headers,
#   - the Nim config files the compiler read (nim.cfg / config.nims),
#   - the Nim compiler itself.
#
# Inputs (-D): NIM, NIM_ARGS ('|'-separated, without --nimcache/--out), NIM_SOURCE,
#              NIMCACHE, OUTPUT, DEPFILE.

foreach(_var NIM NIM_ARGS NIM_SOURCE NIMCACHE OUTPUT DEPFILE)
  if (NOT DEFINED ${_var})
    message(FATAL_ERROR "NimBuildWithDepfile: ${_var} is not set")
  endif()
endforeach()

string(REPLACE "|" ";" _nim_args "${NIM_ARGS}")

# Nim's cache recompiles a {.compile.}'d C/C++ file only when that file itself
# changes, not when a header it includes does. So before reusing the cache:
#   - no cache yet: a fresh build compiles everything anyway;
#   - cache present but no archive (e.g. after `cmake --build --target clean`)
#     or no manifest (first build with this wrapper): we can't tell which
#     headers changed since the cached objects were built, so force a full
#     rebuild (-f);
#   - otherwise force it only if a header from the previous build's inputs is
#     newer than the archive. Other changes stay incremental.
# The inputs are read from a plain one-path-per-line manifest written next to
# the depfile (Make's backslash-continued syntax doesn't read back cleanly).
set(_manifest "${DEPFILE}.inputs")
if (EXISTS "${NIMCACHE}")
  if (NOT EXISTS "${_manifest}" OR NOT EXISTS "${OUTPUT}")
    message(STATUS "No previous build state for the Nim cache: rebuilding all Nim C/C++ objects")
    list(APPEND _nim_args -f)
  else()
    file(STRINGS "${_manifest}" _previous_deps)
    foreach(_dep IN LISTS _previous_deps)
      if (_dep MATCHES "\\.(h|hh|hpp|hxx|inl)$" AND EXISTS "${_dep}"
          AND "${_dep}" IS_NEWER_THAN "${OUTPUT}")
        message(STATUS "Header changed (${_dep}): rebuilding all Nim C/C++ objects")
        list(APPEND _nim_args -f)
        break()
      endif()
    endforeach()
  endif()
endif()

execute_process(
  COMMAND "${NIM}" c ${_nim_args}
          "--nimcache:${NIMCACHE}" "--out:${OUTPUT}" "${NIM_SOURCE}"
  RESULT_VARIABLE _rc)
if (NOT _rc EQUAL 0)
  message(FATAL_ERROR "Nim build failed (${_rc})")
endif()

set(_deps_cache "${NIMCACHE}-deps")
execute_process(
  COMMAND "${NIM}" c ${_nim_args} --genScript:on
          "--nimcache:${_deps_cache}" "${NIM_SOURCE}"
  RESULT_VARIABLE _rc
  OUTPUT_QUIET)
if (NOT _rc EQUAL 0)
  message(FATAL_ERROR "Nim dependency scan failed (${_rc})")
endif()

get_filename_component(_project "${NIM_SOURCE}" NAME_WE)
set(_deps_file "${_deps_cache}/${_project}.deps")
if (NOT EXISTS "${_deps_file}")
  message(FATAL_ERROR "Nim did not write ${_deps_file}")
endif()
file(STRINGS "${_deps_file}" _nim_modules)

set(_deps ${_nim_modules} "${NIM}")

# Sources compiled through {.compile.} pragmas, e.g. seaqt's gen_*.cpp and
# nim-qtcamera's shim.cpp. Paths are relative to the declaring module.
foreach(_module IN LISTS _nim_modules)
  file(STRINGS "${_module}" _pragmas REGEX "\\{\\.compile")
  if (NOT _pragmas)
    continue()
  endif()
  get_filename_component(_dir "${_module}" DIRECTORY)
  foreach(_line IN LISTS _pragmas)
    string(REGEX MATCHALL "\"[^\"]+\\.(c|cc|cpp|cxx|m|mm)\"" _sources "${_line}")
    foreach(_quoted IN LISTS _sources)
      string(REPLACE "\"" "" _src "${_quoted}")
      get_filename_component(_abs "${_src}" ABSOLUTE BASE_DIR "${_dir}")
      if (EXISTS "${_abs}")
        list(APPEND _deps "${_abs}")
        get_filename_component(_base "${_abs}" NAME_WLE)
        get_filename_component(_srcdir "${_abs}" DIRECTORY)
        if (EXISTS "${_srcdir}/${_base}.h")
          list(APPEND _deps "${_srcdir}/${_base}.h")
        endif()
      endif()
    endforeach()
  endforeach()
endforeach()

# Config files Nim read (recorded in the build JSON next to the output).
file(GLOB _json_files "${NIMCACHE}/*.json")
foreach(_json IN LISTS _json_files)
  file(READ "${_json}" _content)
  string(JSON _count ERROR_VARIABLE _err LENGTH "${_content}" configFiles)
  if (_err OR _count EQUAL 0)
    continue()
  endif()
  math(EXPR _last "${_count} - 1")
  foreach(_i RANGE ${_last})
    string(JSON _cfg GET "${_content}" configFiles ${_i})
    list(APPEND _deps "${_cfg}")
  endforeach()
endforeach()

list(REMOVE_DUPLICATES _deps)
string(REPLACE ";" "\n" _manifest_text "${_deps}")
file(WRITE "${_manifest}" "${_manifest_text}\n")

set(_text "${OUTPUT}:")
foreach(_dep IN LISTS _deps)
  string(REPLACE " " "\\ " _dep "${_dep}")
  string(APPEND _text " \\\n  ${_dep}")
endforeach()
file(WRITE "${DEPFILE}" "${_text}\n")
