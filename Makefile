TOP=$(CURDIR)
BUILD_DIR=./build
BUILD_CLIB_DIR=$(BUILD_DIR)/clib
INCLUDE_DIR=./include

CLUALIB=cjson
CLUALIB_TARGET=$(patsubst %, $(BUILD_CLIB_DIR)/%.so, $(CLUALIB))
CFLAGS = -g3 -O2 -rdynamic -Wall -I$(INCLUDE_DIR)

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

$(BUILD_CLIB_DIR)/cjson.so: 3rd/lua-cjson/Makefile
	cd 3rd/lua-cjson && make LUA_INCLUDE_DIR=$(TOP)/$(INCLUDE_DIR)
	mv 3rd/lua-cjson/cjson.so $@

clean:
	rm -rf build

cleanall:
	make clean
	cd skynet && make cleanall