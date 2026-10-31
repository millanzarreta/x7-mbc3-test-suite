RGBASM ?= rgbasm
RGBLINK ?= rgblink
RGBFIX ?= rgbfix

ROOT := ../..
BUILD := $(ROOT)/build
OBJ := $(BUILD)/obj

ROMS := X7POKERTC.gbc
ROM_TARGETS := $(addprefix $(BUILD)/,$(ROMS))
OBJ_TARGETS := $(OBJ)/X7POKERTC.o

all: $(ROM_TARGETS)

$(BUILD) $(OBJ):
	mkdir -p $@

$(OBJ)/X7POKERTC.o: src/X7POKERTC.asm | $(OBJ)
	$(RGBASM) -Wall -o $@ $<

$(BUILD)/X7POKERTC.gbc: $(OBJ)/X7POKERTC.o | $(BUILD)
	$(RGBLINK) -p 0xFF -o $@ $<
	$(RGBFIX) -v $@

clean:
	rm -f $(ROM_TARGETS) $(OBJ_TARGETS)
	rmdir $(OBJ) $(BUILD) 2>/dev/null || true

verify: all
	python3 ../../tools/verify_rgbds_build.py --suite pokertc

.PHONY: all clean verify
