---
layout: home
title: Nix-Ultrafeeder
hero:
  name: Nix-Ultrafeeder
  text: NixOS-native SDR-Enthusiasts Ultrafeeder stack
  tagline: Ultrafeeder, feeders, Skystats, Airband, and auto-update—wired through virtualisation.oci-containers with sane defaults, secrets, and tests.
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: Configuration Guide
      link: /guide/configuration
  image:
    src: /nixos.svg
    alt: NixOS logo
features:
  - title: Nix-first modules
    details: Typed options, mkDefault-friendly defaults, and flake outputs for quick reuse.
  - title: Secure + offline aware
    details: sops-nix integration for secrets; imageFile support to run without registry pulls.
  - title: Full stack covered
    details: Ultrafeeder + feeders (FR24, PiAware, etc.), Airband, Skystats, and container auto-update.
  - title: Batteries included
    details: Defaults module, sample configs, flake examples, and NixOS VM tests for high coverage.
---

## Quick start (flake)

```nix
# flake.nix (snippet)
{
  inputs.nix-ultrafeeder.url = "github:j4v3l/nix-ultrafeeder";

  outputs = { self, nixpkgs, nix-ultrafeeder, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nix-ultrafeeder.nixosModules.ultra
        ({...}: {
          services.ultrafeeder.enable = true;
          services.adsbFeeders.piaware.enable = true;
          # services.airband.enable = true;
          # services.skystats.enable = true;
        })
      ];
    };
  };
}
```

## Essential links

- Get started → [/guide/getting-started](./guide/getting-started.md)
- Configure modules → [/guide/configuration](./guide/configuration.md)
- Secrets & auto-update → [/guide/secrets-updates](./guide/secrets-updates.md)
- Module reference → [/reference/modules](./reference/modules.md)
- Examples & recipes → [/reference/examples](./reference/examples.md)
- Testing → [/reference/testing](./reference/testing.md)

## Project structure

- `modules/nixos/` — Ultrafeeder, feeders, Airband, Skystats, defaults, auto-update, sops integration.
- `examples/` — NixOS configs and flake usage.
- `tests/` — NixOS VM tests for coverage of options and behaviors.
- `secrets/example.secrets.yaml` — Example sops template keys.
- `README.md` — Overview and usage notes.
- `VERSION` — Current release version (release-please).

## Reporting bugs & contact

- Issues: <https://github.com/j4v3l/nix-ultrafeeder/issues>
- Security: see `SECURITY.md`
- Conduct: see `CODE_OF_CONDUCT.md`
- Contributions: see `CONTRIBUTING.md`

## Acknowledgements

- SDR-Enthusiasts for the upstream Docker images and docs.
- NixOS community for `virtualisation.oci-containers` and testing tools.

