# Modules Reference

This page summarizes the provided NixOS modules. See inline option docs in the source for full detail.

## Imports

- `nixosModules.ultrafeeder`: Ultrafeeder container (readsb/tar1090 + feeders entrypoint).
- `nixosModules.skystats`: Skystats + Postgres companion.
- `nixosModules.feeders.*`: PiAware, FlightRadar24, PlaneFinder, AirNav Radar, ADSBHub, OpenSky, RadarVirtuel, Radar1090 UK.
- `nixosModules.airband`: rtlsdr-airband + icecast.
- `nixosModules.defaults`: Shared defaults under `ultra.defaults.*`.
- `nixosModules.containerAutoUpdate`: Timer + service to pull images and restart units on digest change.
- `nixosModules.ultra`: Convenience bundle (`defaults` + `sops-nix` + ultrafeeder + skystats + feeders + airband + sops integration).

## services.ultrafeeder

- Backend: `backend = "docker" | "podman"`.
- Image: `image`, `tag`, or `imageFile` (OCI tarball).
- Env: `environment`, `environmentFiles`, `ultrafeederConfigFragments`, `mlatHubInputs`.
- Ports: `ports`, `openFirewall`.
- Volumes: `volumes`, `createHostDirs` (tmpfiles), `storage.*` (timelapse/offline maps).
- Devices: `device`, `extraOptions` (add multiple `--device`).
- Metrics/telemetry: `prometheus.*`, `telemetry.*` (diskstats/thermal).
- Readsb tuning: `readsb.*` (autogain/gain/ppm/biastee/uat).

## services.skystats

- Image: `image`/`tag` or `imageFile`.
- Postgres: `dbImage`/`dbTag` or `dbImageFile`.
- Required: `readsbAircraftJsonUrl`.
- Database: `database.*` (host/port/user/password/name/dataDir).
- App tuning: `app.*` (lat/lon/radius, etc.).
- Ports + firewall: `ports`, `openFirewall`.

## services.airband

- Image: `image`/`tag` or `imageFile`.
- Device passthrough: `device` (use `extraOptions` for multiples).
- Ports: defaults `8000:8000`, `8001:8001`.
- Env: `environment`/`environmentFiles` (RTLSDRAIRBAND_* / ICECAST_*).
- Volumes: bind mounts for configs/recordings.

## services.adsbFeeders.*

Shared shape across feeders:

- `enable`
- `backend`
- `image`/`tag` or `imageFile`
- `beastHost` / `beastPort` (default: `ultrafeeder:30005`)
- `environment` / `environmentFiles`
- `extraOptions`
- Optional `sops` helper for env-file generation

Feeders included: `piaware`, `flightradar24`, `planefinder`, `airnavradar`, `adsbhub`, `opensky`, `radarvirtuel`, `radar1090uk`.

## services.containerAutoUpdate

- `enable`, `backend`
- `images`: images to pull (defaults to enabled modules)
- `units`: systemd units to restart on digest change (defaults to matching container units)
- `onCalendar`: timer schedule

## ultra.defaults.*

Set once and let modules inherit:

- `ultrafeeder`: backend, image, tag, device, ports, volumes, prometheusPort.
- `feeders`: backend, per-feeder image, feederTag.
- `airband`: backend, image, tag, device, ports, volumes.
- `skystats`: backend, image/tag, dbImage/dbTag.

