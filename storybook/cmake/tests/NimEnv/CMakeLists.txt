# Builds only if storybook_nim_env_var keeps each Windows-style ';'-separated
# assignment one argument of `cmake -E env` (run by ctest: NimEnvCMake).
cmake_minimum_required(VERSION 3.20)
project(NimEnvTest NONE)
include(${CMAKE_CURRENT_SOURCE_DIR}/../../NimEnv.cmake)

set(_path "C:/Windows/System32;C:/Program Files/LLVM/bin;C:/Qt/bin")
set(_pc "C:/a/pkgconfig;C:/b/pkgconfig")
storybook_nim_env_var(_pc_env PKG_CONFIG_PATH "C:/tree/pkgconfig" "${_pc}")
storybook_nim_env_var(_path_env PATH "C:/wrap" "${_path}")
storybook_nim_env_var(_single_env SINGLE "C:/only" "")

add_custom_command(OUTPUT checked.txt
  COMMAND ${CMAKE_COMMAND} -E env ${_pc_env} ${_single_env} ${_path_env}
    ${CMAKE_COMMAND} -DOUT=checked.txt -P ${CMAKE_CURRENT_SOURCE_DIR}/check.cmake
  VERBATIM)
add_custom_target(check ALL DEPENDS checked.txt)
