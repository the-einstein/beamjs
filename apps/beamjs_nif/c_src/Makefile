# BeamJS NIF Makefile
# Compiles QuickJS + NIF bridge into a shared library
# Supports: Linux, macOS, Windows (MinGW)

# Erlang include paths
ERL_ROOT = $(shell erl -noshell -eval "io:format(\"~s\", [code:root_dir()]), halt().")
ERTS_VER = $(shell erl -noshell -eval "io:format(\"~s\", [erlang:system_info(version)]), halt().")
ERTS_INCLUDE = $(ERL_ROOT)/erts-$(ERTS_VER)/include
EI_INCLUDE = $(ERL_ROOT)/usr/include

QUICKJS_DIR = quickjs

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

CC = gcc
CFLAGS = -O2 -fPIC -Wall -Wno-unused-parameter \
         -I$(ERTS_INCLUDE) -I$(EI_INCLUDE) -I$(QUICKJS_DIR) \
         -D_GNU_SOURCE -DCONFIG_VERSION=\"2024-01-13\" \
         -DCONFIG_BIGNUM

# Platform-specific settings
ifeq ($(PLATFORM),darwin)
    LDFLAGS = -dynamiclib -undefined dynamic_lookup -lm -lpthread
    OUTPUT = ../priv/beamjs_nif.so
    MKDIR = mkdir -p
else ifeq ($(PLATFORM),windows)
    # Windows with MinGW
    LDFLAGS = -shared -lm
    OUTPUT = ../priv/beamjs_nif.dll
    MKDIR = if not exist "..\\priv" mkdir "..\\priv"
    # Windows doesn't have -ldl, and pthreads may come from winpthreads
    CFLAGS += -D__USE_MINGW_ANSI_STDIO=1
else
    # Linux
    LDFLAGS = -shared -lm -lpthread -ldl
    OUTPUT = ../priv/beamjs_nif.so
    MKDIR = mkdir -p
endif

# QuickJS source objects
QUICKJS_OBJS = $(QUICKJS_DIR)/quickjs.o \
               $(QUICKJS_DIR)/cutils.o \
               $(QUICKJS_DIR)/libbf.o \
               $(QUICKJS_DIR)/libregexp.o \
               $(QUICKJS_DIR)/libunicode.o

# NIF source objects
NIF_OBJS = beamjs_nif.o term_convert.o host_functions.o module_loader.o

.PHONY: all clean

all: $(OUTPUT)

$(OUTPUT): $(NIF_OBJS) $(QUICKJS_OBJS)
	$(MKDIR) ../priv
	$(CC) -o $@ $^ $(LDFLAGS)
	@echo "NIF built successfully: $@"

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(QUICKJS_DIR)/%.o: $(QUICKJS_DIR)/%.c
	$(CC) $(CFLAGS) -Wno-sign-compare -Wno-missing-field-initializers -c -o $@ $<

clean:
ifeq ($(PLATFORM),windows)
	del /Q $(subst /,\,$(NIF_OBJS) $(QUICKJS_OBJS) $(OUTPUT)) 2>nul || true
else
	rm -f $(NIF_OBJS) $(QUICKJS_OBJS) $(OUTPUT)
endif
