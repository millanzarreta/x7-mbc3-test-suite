.DEFAULT_GOAL := all

RGBDS_VERSION ?= 1.0.4

print-rgbds-version:
	@printf '%s\n' "$(RGBDS_VERSION)"

all:
	$(MAKE) -C diag/rgbds all
	$(MAKE) -C trace/rgbds all
	$(MAKE) -C pokertc/rgbds all

clean:
	rm -rf build

verify-source:
	python3 -B tools/validate_rgbds_transcription.py .

verify-build: all
	python3 -B tools/verify_rgbds_build.py --all

test-tools:
	python3 -B tools/test_inspector.py
	python3 -B tools/test_browser_inspector.py
	python3 -B tools/verify_clear_routine.py .

static-audit:
	python3 -B tools/audit_repository.py

audit:
	$(MAKE) static-audit
	$(MAKE) verify-build
	$(MAKE) verify-source
	$(MAKE) test-tools

.PHONY: print-rgbds-version all clean verify-source verify-build test-tools static-audit audit
