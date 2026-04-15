@echo off
REM BeamJS NIF build script for Windows
REM Uses clang-cl (LLVM/Clang with MSVC compatibility) for QuickJS
REM and MSVC cl for the NIF bridge

setlocal enabledelayedexpansion

REM Get Erlang paths
for /f "tokens=*" %%i in ('erl -noshell -eval "io:format(\"~s\", [code:root_dir()]), halt()."') do set ERL_ROOT=%%i
for /f "tokens=*" %%i in ('erl -noshell -eval "io:format(\"~s\", [erlang:system_info(version)]), halt()."') do set ERTS_VER=%%i

set ERTS_INCLUDE=%ERL_ROOT%\erts-%ERTS_VER%\include
set EI_INCLUDE=%ERL_ROOT%\usr\include
set QUICKJS_DIR=quickjs

echo Building BeamJS NIF for Windows...
echo ERTS_INCLUDE=%ERTS_INCLUDE%

REM Use clang-cl for everything (supports GCC __attribute__ + MSVC ABI)
set CC=clang-cl
set CFLAGS=-O2 -fPIC -Wno-unused-parameter -Wno-sign-compare -Wno-implicit-int-float-conversion ^
    -I"%ERTS_INCLUDE%" -I"%EI_INCLUDE%" -I"%QUICKJS_DIR%" ^
    -D_GNU_SOURCE -DCONFIG_VERSION=\"2024-01-13\" ^
    -DCONFIG_BIGNUM -D_CRT_SECURE_NO_WARNINGS

if not exist "..\priv" mkdir "..\priv"

echo Compiling QuickJS sources...
for %%f in (%QUICKJS_DIR%\quickjs.c %QUICKJS_DIR%\cutils.c %QUICKJS_DIR%\libbf.c %QUICKJS_DIR%\libregexp.c %QUICKJS_DIR%\libunicode.c) do (
    echo   %%f
    %CC% /c %CFLAGS% -Wno-missing-field-initializers %%f
    if !ERRORLEVEL! neq 0 goto :fail
)

echo Compiling NIF sources...
for %%f in (beamjs_nif.c term_convert.c host_functions.c module_loader.c) do (
    echo   %%f
    %CC% /c %CFLAGS% %%f
    if !ERRORLEVEL! neq 0 goto :fail
)

echo Linking...
link /DLL /nologo /OUT:..\priv\beamjs_nif.dll ^
    beamjs_nif.obj term_convert.obj host_functions.obj module_loader.obj ^
    quickjs.obj cutils.obj libbf.obj libregexp.obj libunicode.obj
if %ERRORLEVEL% neq 0 goto :fail

del /Q *.obj 2>nul

echo NIF built successfully: ..\priv\beamjs_nif.dll
exit /b 0

:fail
echo NIF build FAILED
exit /b 1
