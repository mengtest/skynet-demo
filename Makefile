TOP=$(CURDIR)
BUILD_DIR=./build
BUILD_CLIB_DIR=$(BUILD_DIR)/clib
INCLUDE_DIR=./include
3RD_DIR=./3rd
SKYNET_LUA_PATH=$(TOP)/skynet/3rd/lua
CLUALIB=cjson lclient
CLUALIB_TARGET=$(patsubst %, $(BUILD_CLIB_DIR)/%.so, $(CLUALIB))

CC = gcc
CFLAGS = -g3 -O2 -rdynamic -Wall
SHARED = -fPIC --shared

.PHONY: all

all: build-dir
build-dir:
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BUILD_CLIB_DIR)
	mkdir -p $(INCLUDE_DIR)

all: build-skynet
SKYNET_MAKEFILE=skynet/Makefile
$(SKYNET_MAKEFILE):
	git submodule update --init

build-skynet: | $(SKYNET_MAKEFILE)
	cd skynet && make linux

all: $(CLUALIB_TARGET)

$(BUILD_CLIB_DIR)/cjson.so: $(3RD_DIR)/lua-cjson/Makefile
	cd $(3RD_DIR)/lua-cjson && make LUA_INCLUDE_DIR=$(TOP)/$(SKYNET_LUA_PATH)
	mv $(3RD_DIR)/lua-cjson/cjson.so $@

$(BUILD_CLIB_DIR)/lclient.so: client/lua-client.c
	$(CC) $(CFLAGS) $(SHARED) -I$(SKYNET_LUA_PATH) $^ -o $@ -lpthread

all: socket
socket:
	cd $(3RD_DIR)/lsocket/ && make LUA_INCDIR=$(SKYNET_LUA_PATH) && cp lsocket.so $(TOP)/$(BUILD_CLIB_DIR)

all: sproto
sproto:
	export LUA_CPATH=$(TOP)/skynet/luaclib/?.so && cd $(3RD_DIR)/sprotodump/ \
	&& $(SKYNET_LUA_PATH)/lua sprotodump.lua -spb `find -L $(TOP)/common/sproto/  -name "*.sproto"` -o $(TOP)/$(BUILD_DIR)/sproto.spb

clean:
	rm -rf $(BUILD_DIR)

cleanall:
	make clean
	cd skynet && make cleanall