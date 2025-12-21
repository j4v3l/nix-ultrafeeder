# Configuration

`nix-ultrafeeder` ships several NixOS modules. Most users import `nixosModules.defaults` once, then enable the services they need. Key knobs are summarized below.

## Common pattern: shared defaults

```nix
{
  imports = [
    nix-ultrafeeder.nixosModules.defaults
    nix-ultrafeeder.nixosModules.ultra
  ];

  ultra.defaults.ultrafeeder = {
    device = "/dev/bus/usb";
    ports = [ "18080:80" ];
    volumes = [ "/var/tmp/ultra:/var/lib/ultra" ];
  };
}
```

## Module highlights

### `services.ultrafeeder`

- `enable`: turn on the container.
- `backend`: `"docker"` (default) or `"podman"`.
- `image` / `tag` or `imageFile`: pull from GHCR or load a tarball.
- `environment` / `environmentFiles`: pass env vars or env files (great with sops-nix).
- `volumes`: bind mounts; `createHostDirs` (default: true) uses tmpfiles to create host dirs.
- `ports`: host mappings; `openFirewall` opens the matching TCP ports.
- `device`: `--device=...` passthrough (e.g., `/dev/bus/usb`); use `extraOptions` for multiple.
- `prometheus.*`, `storage.*`, `telemetry.*`, `readsb.*`: metrics, timelapse/offline maps, disk/thermal telemetry, and readsb tuning (autogain/gain/ppm/biastee/uat).
- `ultrafeederConfigFragments`, `mlatHubInputs`: compose `ULTRAFEEDER_CONFIG` entries.

### `services.skystats`

- `enable`: run Skystats + Postgres companion.
- `readsbAircraftJsonUrl`: URL to `aircraft.json` (required).
- `database.*`: credentials and `dataDir` path.
- `image`/`tag` + `dbImage`/`dbTag` or `imageFile`/`dbImageFile`.
- `openFirewall`: open UI port(s) if needed.

### `services.airband`

- `enable`: run rtlsdr-airband + icecast.
- `device`: SDR passthrough; use `extraOptions` for multiple.
- `ports`: defaults `8000:8000` (web/audio) and `8001:8001` (Prometheus).
- `environment`/`environmentFiles`: RTLSDRAIRBAND_* and ICECAST_*.

### `services.adsbFeeders.*`

Feeders: `piaware`, `flightradar24`, `planefinder`, `airnavradar`, `adsbhub`, `opensky`, `radarvirtuel`, `radar1090uk`.

- `enable`: turn on the feeder container.
- `beastHost` / `beastPort`: defaults to `ultrafeeder:30005`.
- `environment` / `environmentFiles`: add settings or secrets (works with sops-nix).
- `image`/`tag` or `imageFile`: pull or load locally.

### `services.containerAutoUpdate`

- `enable`, `backend`: docker or podman.
- `images`, `units`: what to pull and which units to restart on digest change (defaults derive from enabled modules).
- `onCalendar`: systemd timer (default: daily).

## Multi-device passthrough

For two SDRs (e.g., 1090 + 978):

```nix
services.ultrafeeder.extraOptions = [
  "--device=/dev/bus/usb/001/002"
  "--device=/dev/bus/usb/001/003"
];
```

## Offline / air-gapped use

Every module supports `imageFile` so you can load OCI tarballs without pulling from GHCR.

