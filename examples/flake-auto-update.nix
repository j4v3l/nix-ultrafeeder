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

            # Optional: metrics/storage/readsb tuning (matches module options)
            # ultrafeeder.prometheus.enable = false; # set true to expose 9273
            # ultrafeeder.storage.timelapseDir = "/opt/adsb/ultrafeeder/timelapse1090";
            # ultrafeeder.storage.offlineMapsDir = "/usr/local/share/osm_tiles_offline";
            # ultrafeeder.telemetry.mountDiskstats = true;
            # ultrafeeder.telemetry.thermalZone = "/sys/class/thermal/thermal_zone0";
            # ultrafeeder.readsb = {
            #   autogain = true;
            #   gain = "autogain";
            #   ppm = 1;
            #   biastee = true;
            #   uat = true; # enable UAT/978
            # };
          };
        })
      ];
    };
  };
}
