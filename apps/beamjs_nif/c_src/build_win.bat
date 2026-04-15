@echo off
REM BeamJS NIF build script for Windows (MSVC)
REM Run from a Visual Studio Developer Command Prompt or with msvc-dev-cmd in CI

setlocal enabledelayedexpansion

REM Get Erlang paths
for /f "tokens=*" %%i in ('erl -noshell -eval "io:format(\"~s\", [code:root_dir()]), halt()."') do set ERL_ROOT=%%i
for /f "tokens=*" %%i in ('erl -noshell -eval "io:format(\"~s\", [erlang:system_info(version)]), halt()."') do set ERTS_VER=%%i

set ERTS_INCLUDE=%ERL_ROOT%\erts-%ERTS_VER%\include
set EI_INCLUDE=%ERL_ROOT%\usr\include
set QUICKJS_DIR=quickjs

echo Building BeamJS NIF for Windows...
echo ERTS_INCLUDE=%ERTS_INCLUDE%

REM Compile NIF sources (C11 mode)
set NIF_CFLAGS=/O2 /nologo /W3 /wd4244 /wd4267 /wd4996 /wd4146 /wd4334 /wd4018 /wd4101 ^
    /I"%ERTS_INCLUDE%" /I"%EI_INCLUDE%" /I"%QUICKJS_DIR%" ^
    /D_GNU_SOURCE /DCONFIG_VERSION="2024-01-13" ^
    /DCONFIG_BIGNUM /D_CRT_SECURE_NO_WARNINGS ^
    /std:c11

echo Compiling NIF sources...
for %%f in (beamjs_nif.c term_convert.c host_functions.c module_loader.c) do (
    echo   %%f
    cl /c %NIF_CFLAGS% %%f
    if !ERRORLEVEL! neq 0 goto :fail
)

REM Compile QuickJS sources
REM QuickJS uses GCC-specific __attribute__ - define it away for MSVC
set QJS_CFLAGS=/O2 /nologo /W3 /wd4244 /wd4267 /wd4996 /wd4146 /wd4334 /wd4018 /wd4101 /wd4473 /wd4090 /wd4028 /wd4113 /wd4098 /wd4477 ^
    /I"%QUICKJS_DIR%" ^
    /D_GNU_SOURCE /DCONFIG_VERSION="2024-01-13" ^
    /DCONFIG_BIGNUM /D_CRT_SECURE_NO_WARNINGS ^
    /D"__attribute__(x)=" /D"inline=__inline" ^
    /std:c11

echo Compiling QuickJS sources...
for %%f in (%QUICKJS_DIR%\quickjs.c %QUICKJS_DIR%\cutils.c %QUICKJS_DIR%\libbf.c %QUICKJS_DIR%\libregexp.c %QUICKJS_DIR%\libunicode.c) do (
    echo   %%f
    cl /c %QJS_CFLAGS% %%f
    if !ERRORLEVEL! neq 0 goto :fail
)

REM Link into DLL
if not exist "..\priv" mkdir "..\priv"
echo Linking...
link /DLL /nologo /OUT:..\priv\beamjs_nif.dll beamjs_nif.obj term_convert.obj host_functions.obj module_loader.obj quickjs.obj cutils.obj libbf.obj libregexp.obj libunicode.obj
if %ERRORLEVEL% neq 0 goto :fail

REM Clean up obj files
del /Q *.obj 2>nul

echo NIF built successfully: ..\priv\beamjs_nif.dll
exit /b 0

:fail
echo NIF build FAILED
exit /b 1
