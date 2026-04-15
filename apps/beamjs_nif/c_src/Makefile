# BeamJS NIF Makefile
# Compiles QuickJS + NIF bridge into a shared library
# Supports: Linux, macOS, Windows (MSVC via nmake or MinGW)

# Platform detection
ifeq ($(OS),Windows_NT)
    PLATFORM = windows
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Darwin)
        PLATFORM = darwin
    else
        PLATFORM = linux
    endif
endif

# Erlang include paths
ERL_ROOT = $(shell erl -noshell -eval "io:format(\"~s\", [code:root_dir()]), halt().")
ERTS_VER = $(shell erl -noshell -eval "io:format(\"~s\", [erlang:system_info(version)]), halt().")
ERTS_INCLUDE = $(ERL_ROOT)/erts-$(ERTS_VER)/include
EI_INCLUDE = $(ERL_ROOT)/usr/include

QUICKJS_DIR = quickjs

# QuickJS source files
QUICKJS_SRCS = $(QUICKJS_DIR)/quickjs.c \
               $(QUICKJS_DIR)/cutils.c \
               $(QUICKJS_DIR)/libbf.c \
               $(QUICKJS_DIR)/libregexp.c \
               $(QUICKJS_DIR)/libunicode.c

# NIF source files
NIF_SRCS = beamjs_nif.c term_convert.c host_functions.c module_loader.c

# Platform-specific settings
ifneq ($(PLATFORM),windows)

# ---- Unix (Linux / macOS) ----
CC = gcc
CFLAGS = -O2 -fPIC -Wall -Wno-unused-parameter \
         -I$(ERTS_INCLUDE) -I$(EI_INCLUDE) -I$(QUICKJS_DIR) \
         -D_GNU_SOURCE -DCONFIG_VERSION=\"2024-01-13\" \
         -DCONFIG_BIGNUM

QJS_CFLAGS = $(CFLAGS) -Wno-sign-compare -Wno-missing-field-initializers

ifeq ($(PLATFORM),darwin)
    LDFLAGS = -dynamiclib -undefined dynamic_lookup -lm -lpthread
else
    LDFLAGS = -shared -lm -lpthread -ldl
endif

OUTPUT = ../priv/beamjs_nif.so

QUICKJS_OBJS = $(QUICKJS_SRCS:.c=.o)
NIF_OBJS = $(NIF_SRCS:.c=.o)

.PHONY: all clean

all: $(OUTPUT)

$(OUTPUT): $(NIF_OBJS) $(QUICKJS_OBJS)
	@mkdir -p ../priv
	$(CC) -o $@ $^ $(LDFLAGS)
	@echo "NIF built successfully: $@"

$(NIF_OBJS): %.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(QUICKJS_OBJS): %.o: %.c
	$(CC) $(QJS_CFLAGS) -c -o $@ $<

clean:
	rm -f $(NIF_OBJS) $(QUICKJS_OBJS) $(OUTPUT)

else

# ---- Windows (MSVC) ----
# Invoked via: nmake or make (with MSVC in PATH from vcvarsall.bat)

CC = cl
CFLAGS = /O2 /nologo /W3 /wd4244 /wd4267 /wd4996 \
         /I"$(ERTS_INCLUDE)" /I"$(EI_INCLUDE)" /I"$(QUICKJS_DIR)" \
         /D_GNU_SOURCE /DCONFIG_VERSION=\"2024-01-13\" \
         /DCONFIG_BIGNUM /D_CRT_SECURE_NO_WARNINGS

EI_LIB = $(ERL_ROOT)/usr/lib
ERTS_LIB = $(ERL_ROOT)/erts-$(ERTS_VER)/lib

OUTPUT = ../priv/beamjs_nif.dll

ALL_SRCS = $(NIF_SRCS) $(QUICKJS_SRCS)

.PHONY: all clean

all: $(OUTPUT)

$(OUTPUT): $(NIF_SRCS) $(QUICKJS_SRCS)
	@if not exist "..\\priv" mkdir "..\\priv"
	$(CC) $(CFLAGS) /LD $(NIF_SRCS) $(QUICKJS_SRCS) /Fe"$(OUTPUT)" /link /LIBPATH:"$(EI_LIB)" /LIBPATH:"$(ERTS_LIB)"
	@echo NIF built successfully: $(OUTPUT)

clean:
	@del /Q *.obj $(subst /,\,$(OUTPUT)) 2>nul || true

endif
