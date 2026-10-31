RGBASM ?= rgbasm
RGBLINK ?= rgblink
RGBFIX ?= rgbfix

ROOT := ../..
BUILD := $(ROOT)/build
OBJ := $(BUILD)/obj

ROMS := X7MBC3TRACE-A.gbc X7MBC3TRACE-B.gbc X7MBC3TRACE-N.gbc
ROM_TARGETS := $(addprefix $(BUILD)/,$(ROMS))
OBJ_TARGETS := $(OBJ)/X7MBC3TRACE-A.o $(OBJ)/X7MBC3TRACE-B.o $(OBJ)/X7MBC3TRACE-N.o

all: $(ROM_TARGETS)

$(BUILD) $(OBJ):
	mkdir -p $@

$(OBJ)/X7MBC3TRACE-A.o: src/X7MBC3TRACE-A.asm | $(OBJ)
	$(RGBASM) -Wall -o $@ $<

$(BUILD)/X7MBC3TRACE-A.gbc: $(OBJ)/X7MBC3TRACE-A.o | $(BUILD)
	$(RGBLINK) -p 0xFF -o $@ $<
	$(RGBFIX) -v $@

$(OBJ)/X7MBC3TRACE-B.o: src/X7MBC3TRACE-B.asm | $(OBJ)
	$(RGBASM) -Wall -o $@ $<

$(BUILD)/X7MBC3TRACE-B.gbc: $(OBJ)/X7MBC3TRACE-B.o | $(BUILD)
	$(RGBLINK) -p 0xFF -o $@ $<
	$(RGBFIX) -v $@

$(OBJ)/X7MBC3TRACE-N.o: src/X7MBC3TRACE-N.asm | $(OBJ)
	$(RGBASM) -Wall -o $@ $<

$(BUILD)/X7MBC3TRACE-N.gbc: $(OBJ)/X7MBC3TRACE-N.o | $(BUILD)
	$(RGBLINK) -p 0xFF -o $@ $<
	$(RGBFIX) -v $@

clean:
	rm -f $(ROM_TARGETS) $(OBJ_TARGETS)
	rmdir $(OBJ) $(BUILD) 2>/dev/null || true

verify: all
	python3 ../../tools/verify_rgbds_build.py --suite trace

.PHONY: all clean verify
