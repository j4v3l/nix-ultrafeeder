## nix-ultrafeeder (Ultrafeeder + Skystats on NixOS)
[![CI](https://github.com/j4v3l/nix-ultrafeeder/actions/workflows/ci.yml/badge.svg)](https://github.com/j4v3l/nix-ultrafeeder/actions/workflows/ci.yml)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Nix](https://img.shields.io/badge/Nix-flakes-5277C3?logo=nixos&logoColor=white)
![NixOS](https://img.shields.io/badge/NixOS-25.11-5277C3?logo=nixos&logoColor=white)

This repo is a small Nix flake that provides a **NixOS module** to run
[`sdr-enthusiasts/docker-adsb-ultrafeeder`](https://github.com/sdr-enthusiasts/docker-adsb-ultrafeeder)
and [`tomcarman/skystats`](https://github.com/tomcarman/skystats) using `virtualisation.oci-containers`
(Docker or Podman), with **sops/age** support for secrets.

### What you get

- **`nixosModules.ultrafeeder`**: Configures an `oci-containers` container named `ultrafeeder`
- **`nixosModules.skystats`**: Configures `skystats` + a companion `postgres` container (matches the upstream Docker setup)
- **`nixosModules.piaware`**, **`nixosModules.flightradar24`**, **`nixosModules.planefinder`**, **`nixosModules.airnavradar`**: Optional feeder containers that read from Ultrafeeder’s BEAST port
- **`nixosModules.ultra`**: Convenience module that imports **`sops-nix`** + both services + secret integration
- **Typed options** for env vars, ports, volumes, backend choice, and basic host-dir creation

### Use in your system flake

Add this repo as an input and import the modules you want:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-ultrafeederfeeder.url = "path:/absolute/path/to/nix-ultrafeeder";
  };

  outputs = { self, nixpkgs, nix-ultrafeeder, ... }: {
    nixosConfigurations.myHost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Includes sops-nix + both services + env-file secret injection helpers:
        nix-ultrafeeder.nixosModules.ultra
        ({ ... }: {
          services.ultrafeeder.enable = true;
          services.ultrafeeder.environment = {
            TZ = "UTC";
            READSB_DEVICE_TYPE = "rtlsdr";
          };
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
- **`environment`**: env vars passed to the container
- **`volumes`**: bind mounts (optionally created via tmpfiles if `createHostDirs = true`)
- **`ports`**: port mappings (defaults expose web UI + common readsb ports)
- **`device`**: optional `--device=...` passthrough (e.g. `/dev/bus/usb`)
- **`openFirewall`**: if true, opens firewall for simple `HOSTPORT:...` entries in `ports`
- **`ultrafeederConfigFragments`**: append extra `ULTRAFEEDER_CONFIG` fragments
- **`mlatHubInputs`**: convenience for `ULTRAFEEDER_CONFIG=mlathub,...` ingest of external MLAT results (e.g. from PiAware)

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

### Example

See `examples/nixos-configuration.nix`.
