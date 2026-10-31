RGBASM ?= rgbasm
RGBLINK ?= rgblink
RGBFIX ?= rgbfix

ROOT := ../..
BUILD := $(ROOT)/build
OBJ := $(BUILD)/obj

ROMS := X7MBC3DIAG-A.gbc X7MBC3DIAG-B.gbc X7MBC3DIAG-N.gbc
ROM_TARGETS := $(addprefix $(BUILD)/,$(ROMS))
OBJ_TARGETS := $(OBJ)/X7MBC3DIAG-A.o $(OBJ)/X7MBC3DIAG-B.o $(OBJ)/X7MBC3DIAG-N.o

all: $(ROM_TARGETS)

$(BUILD) $(OBJ):
	mkdir -p $@

$(OBJ)/X7MBC3DIAG-A.o: src/X7MBC3DIAG-A.asm | $(OBJ)
	$(RGBASM) -Wall -o $@ $<

$(BUILD)/X7MBC3DIAG-A.gbc: $(OBJ)/X7MBC3DIAG-A.o | $(BUILD)
	$(RGBLINK) -p 0xFF -o $@ $<
	$(RGBFIX) -v $@

$(OBJ)/X7MBC3DIAG-B.o: src/X7MBC3DIAG-B.asm | $(OBJ)
	$(RGBASM) -Wall -o $@ $<

$(BUILD)/X7MBC3DIAG-B.gbc: $(OBJ)/X7MBC3DIAG-B.o | $(BUILD)
	$(RGBLINK) -p 0xFF -o $@ $<
	$(RGBFIX) -v $@

$(OBJ)/X7MBC3DIAG-N.o: src/X7MBC3DIAG-N.asm | $(OBJ)
	$(RGBASM) -Wall -o $@ $<

$(BUILD)/X7MBC3DIAG-N.gbc: $(OBJ)/X7MBC3DIAG-N.o | $(BUILD)
	$(RGBLINK) -p 0xFF -o $@ $<
	$(RGBFIX) -v $@

clean:
	rm -f $(ROM_TARGETS) $(OBJ_TARGETS)
	rmdir $(OBJ) $(BUILD) 2>/dev/null || true

verify: all
	python3 ../../tools/verify_rgbds_build.py --suite diag

.PHONY: all clean verify
