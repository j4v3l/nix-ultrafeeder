{
  description = "Example flake: ultrafeeder + skystats + container auto-update";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-ultrafeeder.url = "github:j4v3l/nix-ultrafeeder";
  };

  outputs = {
    nixpkgs,
    nix-ultrafeeder,
    ...
  }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Include the main services + sops integration helper:
        nix-ultrafeeder.nixosModules.ultra
        # Optional auto-updater module:
        nix-ultrafeeder.nixosModules.containerAutoUpdate
        (_: {
          services = {
            ultrafeeder.enable = true;
            skystats.enable = true;
            containerAutoUpdate = {
              enable = true;
              backend = "docker"; # or "podman"
              onCalendar = "*-*-* 03:00:00"; # daily at 03:00
              # images/units default to the enabled modules above; override if needed:
              # images = [ "ghcr.io/sdr-enthusiasts/docker-adsb-ultrafeeder:latest" ];
              # units = [ "docker-ultrafeeder.service" "docker-skystats.service" ];
            };
          };
        })
      ];
    };
  };
}
