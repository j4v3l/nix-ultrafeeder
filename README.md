# nix-ultrafeeder (Ultrafeeder + Skystats on NixOS)

[![CI](https://github.com/j4v3l/nix-ultrafeeder/actions/workflows/ci.yml/badge.svg)](https://github.com/j4v3l/nix-ultrafeeder/actions/workflows/ci.yml)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Nix](https://img.shields.io/badge/Nix-flakes-5277C3?logo=nixos&logoColor=white)
![NixOS](https://img.shields.io/badge/NixOS-25.11-5277C3?logo=nixos&logoColor=white)

This repo is a small Nix flake that provides a **NixOS module** to run
[`sdr-enthusiasts/docker-adsb-ultrafeeder`](https://github.com/sdr-enthusiasts/docker-adsb-ultrafeeder)
and [`tomcarman/skystats`](https://github.com/tomcarman/skystats) using `virtualisation.oci-containers`
(Docker or Podman), with **sops/age** support for secrets.

## What you get

- **`nixosModules.ultrafeeder`**: Configures an `oci-containers` container named `ultrafeeder`
- **`nixosModules.skystats`**: Configures `skystats` + a companion `postgres` container (matches the upstream Docker setup)
- **`nixosModules.piaware`**, **`nixosModules.flightradar24`**, **`nixosModules.planefinder`**, **`nixosModules.airnavradar`**: Optional feeder containers that read from Ultrafeeder’s BEAST port
- **`nixosModules.adsbhub`**, **`nixosModules.opensky`**, **`nixosModules.radarvirtuel`**, **`nixosModules.radar1090uk`**: Additional feeder containers
- **`nixosModules.airband`**: Runs rtlsdr-airband + icecast for ATC audio
- **`nixosModules.ultra`**: Convenience module that imports **`sops-nix`** + both services + secret integration
- **`nixosModules.containerAutoUpdate`**: Optional timered auto-pull + restart helper for docker/podman images used here
- **`nixosModules.defaults`**: Shared defaults you can override once under `ultra.defaults.*`
- **Shared network**: All containers join the bridge network `ultra-net` by default; override with `ultra.defaults.network.*` or per-service `networkName`
- **Typed options** for env vars, ports, volumes, backend choice, and basic host-dir creation

### Host prep (RTL-SDR)

If you use RTL-SDR dongles, blacklist the DVB kernel modules so the containers can claim the devices (otherwise you’ll see “Device or resource busy”). Follow the SDR-Enthusiasts guide: https://sdr-enthusiasts.gitbook.io/ads-b/setting-up-rtl-sdrs/blacklist-kernel-modules

### Use in your system flake

Add this repo as an input and import the modules you want:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-ultrafeeder.url = "github:j4v3l/nix-ultrafeeder";
  };

  outputs = { self, nixpkgs, nix-ultrafeeder, ... }: {
    nixosConfigurations.myHost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Includes shared defaults + sops-nix + both services + env-file secret injection helpers:
        nix-ultrafeeder.nixosModules.defaults
        nix-ultrafeeder.nixosModules.ultra
        # Optional: auto-update container images and restart on digest changes:
        nix-ultrafeeder.nixosModules.containerAutoUpdate
        ({ ... }: {
          services.ultrafeeder.enable = true;
          services.ultrafeeder.environment = {
            TZ = "UTC";
            READSB_DEVICE_TYPE = "rtlsdr";
          };
          # Offline / air-gapped? Preload an OCI tarball instead of pulling:
          # services.ultrafeeder.imageFile = /path/to/ultrafeeder-image.tar.gz;
          services.ultrafeeder.volumes = [
            "/opt/adsb/ultrafeeder/globe_history:/var/globe_history"
            "/opt/adsb/ultrafeeder/collectd:/var/lib/collectd"
          ];
          services.ultrafeeder.device = "/dev/bus/usb";

          # Skystats consumes readsb's aircraft.json (served by ultrafeeder's web UI)
          services.skystats.enable = true;
          services.skystats.readsbAircraftJsonUrl = "http://192.168.1.100:8080/data/aircraft.json";
          services.skystats.app = {
            lat = "51.5074";
            lon = "-0.1278";
            radiusKm = 1000;
            aboveRadiusKm = 20;
            domesticCountryIso = "GB";
            logLevel = "INFO";
          };

          services.containerAutoUpdate = {
            enable = true;
            backend = "docker"; # or "podman"
            onCalendar = "*-*-* 03:00:00"; # daily at 03:00
            # images/units default to the enabled modules; override if needed
          };

          # Device passthrough: set once via ultra.defaults.ultrafeeder.device
          # or per-host here. For multiple devices, use extraOptions with
          # repeated --device entries.
          # services.ultrafeeder.device = "/dev/bus/usb";
          # services.ultrafeeder.extraOptions = [
          #   "--device=/dev/bus/usb/001/002"
          #   "--device=/dev/bus/usb/001/003"
          # ];
        })
      ];
    };
  };
}
```

### Secrets with sops + age (recommended)

Skystats requires a Postgres password; Ultrafeeder often uses API keys / feeder credentials depending on your config.
This repo supports secrets via **`sops-nix`** templates, which render a runtime env file in `/run/secrets/...` and
pass it into the container as an `environmentFile` (so secrets do **not** end up in the Nix store).

- **Generate an age key** (on the NixOS host) and store it somewhere root-owned, e.g. `/var/lib/sops-nix/key.txt`.
- **Encrypt a secrets file** (example keys are in `secrets/example.secrets.yaml`).
- **Enable the secret injection** in your NixOS config:

```nix
{
  ultra.sops.ageKeyFile = "/var/lib/sops-nix/key.txt";
  ultra.sops.defaultSopsFile = "/etc/nixos/secrets.yaml";

  # Skystats: inject DB passwords into both the app and postgres containers
  services.skystats.sops = {
    enable = true;
    sopsFile = "/etc/nixos/secrets.yaml";
    # Defaults already map DB_PASSWORD/POSTGRES_PASSWORD to "skystats_db_password"
  };

  # Ultrafeeder: map whichever env vars you consider secrets to keys in your sops file
  services.ultrafeeder.sops = {
    enable = true;
    sopsFile = "/etc/nixos/secrets.yaml";
    envToSecret = {
      FEEDER_KEY = "ultrafeeder_feeder_key";
      MLAT_USER = "ultrafeeder_mlat_user";
      MLAT_PASSWORD = "ultrafeeder_mlat_password";
    };
  };
}
```

### Feeding to FlightAware / FR24 / PlaneFinder / AirNav Radar

These are typically run as **separate feeder containers** that connect to Ultrafeeder via BEAST (usually `ultrafeeder:30005`).
This flake provides simple NixOS modules under `services.adsbFeeders.*`:

- `services.adsbFeeders.piaware` (FlightAware / PiAware) — secret: `FEEDER_ID`
- `services.adsbFeeders.flightradar24` — secret: `FR24KEY` (+ optional `FR24KEY_UAT`)
- `services.adsbFeeders.planefinder` — secret: `SHARECODE`
- `services.adsbFeeders.airnavradar` — secret: `SHARING_KEY`

Each supports `environmentFiles` so you can inject keys via sops-nix templates.

### MLAT (logical setup)

There are two common MLAT patterns:

- **Built-in MLAT from Ultrafeeder** (recommended for most aggregators): configure MLAT targets in `ULTRAFEEDER_CONFIG` (or `services.ultrafeeder.ultrafeederConfigFragments`).
- **External MLAT client (PiAware)**: PiAware can run MLAT and expose MLAT results; Ultrafeeder can ingest those results so they show up on tar1090.

This flake provides a helper for the second case:

- **Enable MLAT in PiAware**: `services.adsbFeeders.piaware.allowMlat = true;`
- **Ingest PiAware MLAT results into Ultrafeeder**:
  - `services.ultrafeeder.mlatHubInputs = [{ host = "piaware"; port = 30105; protocol = "beast_in"; }];`

Ultrafeeder documentation about MLAT hub ingest and external MLAT return data is in
[`sdr-enthusiasts/docker-adsb-ultrafeeder`](https://github.com/sdr-enthusiasts/docker-adsb-ultrafeeder).

### Options

Module namespace: **`services.ultrafeeder`**

- **`enable`**: enable the container
- **`backend`**: `"docker"` (default) or `"podman"`
- **`image`** / **`tag`**: image reference (defaults to GHCR `:latest`)
- **`imageFile`**: optional OCI tarball to load instead of pulling (good for offline tests/hosts)
- **`environment`**: env vars passed to the container
- **`environmentFiles`**: env files passed through (pairs well with sops-nix templates)
- **`volumes`**: bind mounts (optionally created via tmpfiles if `createHostDirs = true`)
- **`createHostDirs`**: create host dirs for volume sources via tmpfiles (default: true)
- **`ports`**: port mappings (defaults expose 8080/30003/30005/30104)
- **`device`**: optional `--device=...` passthrough (e.g. `/dev/bus/usb`)
- **`openFirewall`**: if true, opens firewall for simple `HOSTPORT:...` entries in `ports`
- **`extraOptions`**: extra CLI flags to the backend (e.g. `--network=host`)
- **`ultrafeederConfigFragments`**: append extra `ULTRAFEEDER_CONFIG` fragments
- **`mlatHubInputs`**: convenience for `ULTRAFEEDER_CONFIG=mlathub,...` ingest of external MLAT results (e.g. from PiAware)
- **`prometheus.*`**: enable Prometheus/telegraf metrics and map the metrics port (defaults to `9273:9273`)
- **`storage.*`**: convenience mounts for timelapse1090 data and offline map tiles
- **`telemetry.*`**: optional diskstats/thermal zone mounts for graphs1090 metrics
- **`readsb.*`**: toggles for autogain, gain, ppm, biastee, and UAT/978

Module namespace: **`services.airband`**

- **`enable`**: run the rtlsdr-airband + icecast container
- **`backend`**: docker (default) or podman
- **`image`/`tag`**: defaults to `ghcr.io/sdr-enthusiasts/docker-rtlsdrairband:latest`
- **`device`**: optional SDR device to pass through (use extraOptions for multiple)
- **`environment`/`environmentFiles`**: pass RTLSDRAIRBAND_*/ICECAST_* and secrets
- **`volumes`**: e.g., `/opt/adsb/airband:/run/rtlsdr-airband` for custom configs/recordings
- **`ports`**: defaults to `8000:8000` (icecast/web) and `8001:8001` (Prometheus stats)

Module namespace: **`services.skystats`**

- **`enable`**: enable the Skystats + Postgres containers
- **`image`** / **`tag`**: Skystats image (defaults to `ghcr.io/tomcarman/skystats:latest`)
- **`dbImage`** / **`dbTag`**: Postgres image (defaults to `postgres:17`)
- **`readsbAircraftJsonUrl`**: URL to `aircraft.json` served by readsb/tar1090 (required by Skystats)
- **`database.*`**: host/port/user/password/name + `dataDir` for persistence
- **`app.*`**: receiver lat/lon and stats tuning options
- **`ports`**: defaults to exposing the UI on `5173:80` (same as upstream docs)
- **`openFirewall`**: optionally open firewall for the UI port(s)

Module namespace: **`services.adsbFeeders.*`**

- **`services.adsbFeeders.<feeder>.enable`**: enable a feeder container
- **`beastHost` / `beastPort`**: where to read BEAST data (defaults to `ultrafeeder:30005`)
- **`environment` / `environmentFiles`**: extra env vars + secret injection support
- **`<feeder>.sops.*`**: enable sops-nix env file generation for that feeder’s key(s)

Module namespace: **`services.containerAutoUpdate`**

- **`enable`**: turn on the auto-update timer/service (default: disabled)
- **`backend`**: `"docker"` (default) or `"podman"`; used for pulls/restarts
- **`images`**: list of images to `pull` (defaults to images from enabled modules)
- **`units`**: systemd units to restart on digest change (defaults to matching containers for enabled modules, e.g. `docker-ultrafeeder.service`)
- **`onCalendar`**: systemd timer schedule (default: `daily`)

### Example

See `examples/nixos-configuration.nix` (module usage) and `examples/flake-auto-update.nix` (full flake including the auto-update helper).

### Releases & versioning

- Version is tracked in `VERSION` and exposed via flake outputs:
  - `nix eval .#packages.x86_64-linux.version`
  - `nix run .#version`
- Releases are automated via GitHub Actions (`release-please`):
  - Push/merge to `main` → Release PR with changelog + version bump.
  - Merging that PR tags `vX.Y.Z`, publishes GitHub Release notes, and updates `CHANGELOG.md`.
