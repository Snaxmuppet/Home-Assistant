# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is a Home Assistant configuration directory running HA **2026.5.1**. It is not a software project with a build system — it is a live configuration that HA reads directly at runtime. There are no build, lint, or test commands; changes take effect after reloading HA or the relevant domain (e.g. via **Developer Tools → YAML → Reload**).

To validate YAML before applying it, use the HA **Developer Tools → Check Configuration** button in the UI, or call the `homeassistant.check_config` service.

## Configuration structure

| Path | Purpose |
|---|---|
| `configuration.yaml` | Main entry point — loads all other files |
| `automations.yaml` | All UI-managed automations (managed by HA; do not reorder manually) |
| `scripts.yaml` | Scripts |
| `scenes.yaml` | Scenes |
| `groups.yaml` | Light/device groups |
| `packages/hod.yaml` | Heat on Demand system (see below) |
| `pyscript/` | Python scripts exposed as HA services via the pyscript custom component |
| `blueprints/` | Automation and script blueprints |
| `zigbee2mqtt/configuration.yaml` | Zigbee2MQTT broker config, device friendly-name map |
| `themes/mushroom/` | Mushroom theme variants |
| `esphome/` | ESPHome device configs |
| `solcast_solar/` | Solcast PV forecast cache files (JSON, do not edit) |

Helper entities (input_boolean, input_text, input_datetime, input_number, input_select, timer, schedule) live in `.storage/` files managed by HA — do **not** edit those files directly. Helpers that belong to the HOD package are defined in YAML inside `packages/hod.yaml`.

## Key systems

### Heat on Demand (HOD) — `packages/hod.yaml`
Custom TRV-driven boiler controller. Architecture:
1. **Raw demand** binary sensors — one per room, true when the Better Thermostat `hvac_action == 'heating'`.
2. **Effective demand** binary sensors — gated by per-room master (`input_boolean.hod_master_<room>`) and global master (`input_boolean.hod_master`).
3. **Global demand** binary sensor — OR of all effective demands; drives the single automation.
4. **Automation** `hod_boiler_control_with_cooldown` — sets `climate.home_thermostat` to heat/off; includes a 10-minute cooldown after any raw TRV change. Sends Telegram notifications on state change.

To add a room: add an `input_boolean.hod_master_<room>`, a `_demand_raw` sensor, a `_demand` sensor, wire the room master into `hod_any_room_master_on`, and add the raw sensor to the automation trigger list.

### Energy / Octopus Agile
- Octopus Agile prices published to MQTT topic `agile/currentPeriodPrice` → `sensor.current_agile_price`.
- `sensor.tomorrow_soc_target` (in `configuration.yaml`) calculates a recommended battery SoC using Solcast half-hourly PV forecast, a 7.6 kWh / 86 % efficiency battery model, and a morning load floor.

### EcoFlow PowerStream — `pyscript/set_ef_powerstream_custom_load_power.py`
A pyscript `@service` that calls the EcoFlow cloud API to set `permanentWatts` on a PowerStream inverter. API credentials (accessKey/secretKey) are hardcoded in the file.

### Zigbee2MQTT
Runs as a separate service. Config at `zigbee2mqtt/configuration.yaml`. MQTT broker at `mqtt://10.10.10.146:1883`. Zigbee coordinator exposed over TCP at `192.168.200.92:6638`. Device IEEE addresses are mapped to friendly names there.

### Custom components (installed via HACS)
Notable ones that have significant YAML surface area:
- **better_thermostat** — virtual climate entities (`climate.btrv_*`) wrapping physical TRV Zigbee devices; used by HOD.
- **octopus_energy** — Octopus Energy UK tariff, consumption, and intelligent EV charging entities.
- **area_occupancy** — probabilistic room occupancy detection backed by an SQLite DB (`.storage/area_occupancy.db`).
- **solcast_solar** — PV yield forecasting; cache in `solcast_solar/*.json`.
- **ecoflow_cloud** — EcoFlow device sensors (Stream 1/2, Stream AC Pro batteries).
- **pyscript** — allows Python scripts in `pyscript/` to be called as HA services.
- **scheduler** — schedule-based automations stored in `.storage/scheduler.storage`.

## YAML conventions used here

- `!include <file>` for single files, `!include_dir_merge_named <dir>` for merging named dicts from a directory (used for `packages/` and `themes/`).
- Template sensors use the modern `template:` block format (not the legacy `sensor: - platform: template`).
- Automations edited through the UI are written in `automations.yaml` with numeric `id:` strings; manual YAML automations (HOD) live in `packages/hod.yaml` with human-readable `id:` values.
- `secrets.yaml` holds a small number of credentials; reference with `!secret <key>`. Some credentials (EmonCMS API key, SMTP password, EcoFlow API keys) are currently hardcoded in `configuration.yaml` and `pyscript/`.

## Notifications
Two channels are used:
- **Telegram** (`telegram_bot.send_message`) — used by HOD boiler automation.
- **SMTP via Fastmail** (`notify.email_me`) — configured in `configuration.yaml`; currently commented out in HOD actions.
