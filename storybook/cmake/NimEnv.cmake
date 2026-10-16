# storybook_nim_env_var(<out> <name> <prepend> <inherited>): one `cmake -E env`
# assignment, <name>=<prepend>;<inherited>, for Windows-style ';'-separated
# variables (PATH, PKG_CONFIG_PATH). Every ';' (the inherited value's own
# included) is written as $<SEMICOLON>, so the assignment stays one argument
# when the list is expanded into a custom command.
function(storybook_nim_env_var out name prepend inherited)
  string(REPLACE ";" "$<SEMICOLON>" inherited "${inherited}")
  if ("${inherited}" STREQUAL "")
    set(${out} "${name}=${prepend}" PARENT_SCOPE)
  else()
    set(${out} "${name}=${prepend}$<SEMICOLON>${inherited}" PARENT_SCOPE)
  endif()
endfunction()
