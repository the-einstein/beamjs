@echo off
REM BeamJS NIF build script for Windows (MSVC)
REM Run this from a Visual Studio Developer Command Prompt

setlocal

REM Get Erlang paths
for /f "tokens=*" %%i in ('erl -noshell -eval "io:format(\"~s\", [code:root_dir()]), halt()."') do set ERL_ROOT=%%i
for /f "tokens=*" %%i in ('erl -noshell -eval "io:format(\"~s\", [erlang:system_info(version)]), halt()."') do set ERTS_VER=%%i

set ERTS_INCLUDE=%ERL_ROOT%\erts-%ERTS_VER%\include
set EI_INCLUDE=%ERL_ROOT%\usr\include
set QUICKJS_DIR=quickjs

echo Building BeamJS NIF for Windows...
echo ERTS_INCLUDE=%ERTS_INCLUDE%

set CFLAGS=/O2 /nologo /W3 /wd4244 /wd4267 /wd4996 /wd4146 /wd4334 ^
    /I"%ERTS_INCLUDE%" /I"%EI_INCLUDE%" /I"%QUICKJS_DIR%" ^
    /D_GNU_SOURCE /DCONFIG_VERSION="2024-01-13" ^
    /DCONFIG_BIGNUM /D_CRT_SECURE_NO_WARNINGS

set NIF_SRCS=beamjs_nif.c term_convert.c host_functions.c module_loader.c
set QJS_SRCS=%QUICKJS_DIR%\quickjs.c %QUICKJS_DIR%\cutils.c %QUICKJS_DIR%\libbf.c %QUICKJS_DIR%\libregexp.c %QUICKJS_DIR%\libunicode.c

if not exist "..\priv" mkdir "..\priv"

cl %CFLAGS% /LD %NIF_SRCS% %QJS_SRCS% /Fe"..\priv\beamjs_nif.dll" /link
if %ERRORLEVEL% neq 0 (
    echo NIF build FAILED
    exit /b 1
)

REM Clean up obj files
del /Q *.obj 2>nul

echo NIF built successfully: ..\priv\beamjs_nif.dll
