# Terminology

## ARM

`ARM` creates a forensic boundary before an external operation the ROM cannot
perform itself. On the next boot the suite audits monitored SRAM before ordinary
RTC activity. See [`lifecycle-arm.md`](lifecycle-arm.md).

## PRESET

A **PRESET** is functional state preparation used by TRACE. A preset may perform
defined read-only preparation and determines the final MBC3 selector/state left
immediately before the ARMED boundary.

PRESET therefore has technical meaning and is not interchangeable with SCENARIO.

## SCENARIO

A **SCENARIO** is an opaque user-defined numeric metadata tag attached to an ARM
experiment.

Rules:

- range `01..FF`;
- `00` is the default/unarmed value;
- choosing a scenario does not perform an external action;
- the ROM assigns no built-in meaning to a scenario number;
- the selected byte is preserved in ARM/EXT_PASS/FAULT forensic records.

DIAG uses SCENARIO directly. TRACE uses PRESET + SCENARIO. POKERTC has no ARM
subsystem.
