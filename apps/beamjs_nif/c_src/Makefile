# BeamJS NIF Makefile (Linux / macOS)
# For Windows, use build_win.bat with MSVC

# Erlang include paths
ERL_ROOT = $(shell erl -noshell -eval "io:format(\"~s\", [code:root_dir()]), halt().")
ERTS_VER = $(shell erl -noshell -eval "io:format(\"~s\", [erlang:system_info(version)]), halt().")
ERTS_INCLUDE = $(ERL_ROOT)/erts-$(ERTS_VER)/include
EI_INCLUDE = $(ERL_ROOT)/usr/include

QUICKJS_DIR = quickjs

# Platform detection
UNAME_S := $(shell uname -s)

CC = gcc
CFLAGS = -O2 -fPIC -Wall -Wno-unused-parameter \
         -I$(ERTS_INCLUDE) -I$(EI_INCLUDE) -I$(QUICKJS_DIR) \
         -D_GNU_SOURCE -DCONFIG_VERSION=\"2024-01-13\" \
         -DCONFIG_BIGNUM

QJS_CFLAGS = $(CFLAGS) -Wno-sign-compare -Wno-missing-field-initializers

ifeq ($(UNAME_S),Darwin)
    LDFLAGS = -dynamiclib -undefined dynamic_lookup -lm -lpthread
else
    LDFLAGS = -shared -lm -lpthread -ldl
endif

OUTPUT = ../priv/beamjs_nif.so

QUICKJS_OBJS = $(QUICKJS_DIR)/quickjs.o $(QUICKJS_DIR)/cutils.o \
               $(QUICKJS_DIR)/libbf.o $(QUICKJS_DIR)/libregexp.o \
               $(QUICKJS_DIR)/libunicode.o

NIF_OBJS = beamjs_nif.o term_convert.o host_functions.o module_loader.o

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
