@echo off
rem Generic pkg-config wrapper for native Windows (cmd.exe).
rem
rem Windows companion to the POSIX `pkg-config` sh script in this directory.
rem When Nim's `gorge("pkg-config ...")` (or the Makefile) runs under native
rem cmd.exe, the bare name `pkg-config` resolves to THIS .cmd via PATHEXT,
rem while MSYS/Cygwin bash picks the extensionless sh script instead.
rem
rem Forces --define-prefix so Qt's relocatable .pc files resolve ${prefix}
rem from their actual on-disk location. The real pkg-config/pkgconf is found
rem from PATH at runtime (no hard-coded path) via `where`, skipping this
rem wrapper's own directory to avoid infinite self-recursion.
setlocal enableextensions enabledelayedexpansion

set "self_dir=%~dp0"
if "%self_dir:~-1%"=="\" set "self_dir=%self_dir:~0,-1%"

set "real="
for %%P in (pkg-config.exe pkg-config pkgconf.exe pkgconf) do (
  if not defined real (
    for /f "delims=" %%I in ('where %%P 2^>nul') do (
      if not defined real (
        set "cand_dir=%%~dpI"
        if "!cand_dir:~-1!"=="\" set "cand_dir=!cand_dir:~0,-1!"
        if /I not "!cand_dir!"=="%self_dir%" set "real=%%I"
      )
    )
  )
)

if not defined real (
  echo pkg-config wrapper: no real pkg-config/pkgconf found on PATH 1>&2
  exit /b 127
)

"%real%" --define-prefix %*
exit /b %errorlevel%
