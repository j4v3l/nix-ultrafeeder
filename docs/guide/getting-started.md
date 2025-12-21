# Getting Started

This guide shows how to add `nix-ultrafeeder` to a NixOS flake, enable Ultrafeeder and Skystats, and run with Docker or Podman.

## Prerequisites

- Nix with flakes enabled.
- NixOS host with Docker or Podman available (`virtualisation.oci-containers` handles the backend).
- For RTL-SDR devices: blacklist DVB kernel modules so the containers can claim the dongles (see the SDR-Enthusiasts guide).

## Add the flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-ultrafeeder.url = "github:j4v3l/nix-ultrafeeder";
  };
}
```

## Minimal host configuration

```nix
{
  outputs = { self, nixpkgs, nix-ultrafeeder, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nix-ultrafeeder.nixosModules.defaults
          nix-ultrafeeder.nixosModules.ultra
          ({ ... }: {
            services.ultrafeeder = {
              enable = true;
              backend = "docker"; # or "podman"
              environment = {
                TZ = "UTC";
                READSB_DEVICE_TYPE = "rtlsdr";
              };
              # Optional: preload a tarball instead of pulling
              # imageFile = /path/to/ultrafeeder-image.tar.gz;
              device = "/dev/bus/usb";
              volumes = [
                "/opt/adsb/ultra/globe_history:/var/globe_history"
              ];
            };

            services.skystats = {
              enable = true;
              readsbAircraftJsonUrl = "http://ultrafeeder:8080/data/aircraft.json";
              database.password = "changeme"; # use sops-nix in production
            };
          })
        ];
      };
    };
}
```

## Optional: auto-update timer

```nix
{
  modules = [
    nix-ultrafeeder.nixosModules.containerAutoUpdate
    ({ ... }: {
      services.containerAutoUpdate = {
        enable = true;
        backend = "docker";
        onCalendar = "*-*-* 03:00:00";
      };
    })
  ];
}
```

## Apply and verify

```bash
sudo nixos-rebuild switch --flake .#my-host
sudo systemctl status docker-ultrafeeder.service
sudo systemctl status docker-skystats.service
```

Next: dive into configuration details in [/guide/configuration](./configuration.md).

