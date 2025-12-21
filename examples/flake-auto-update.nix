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

            # Optional: metrics/storage/readsb tuning (matches module options) and airband
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

            # Optional: devices (set once via ultra.defaults.ultrafeeder.device or per-host).
            # For multiple devices, use extraOptions with multiple --device entries.
            # ultrafeeder.device = "/dev/bus/usb";
            # ultrafeeder.extraOptions = [
            #   "--device=/dev/bus/usb/001/002"
            #   "--device=/dev/bus/usb/001/003"
            # ];

            # services.airband.enable = true;
            # services.airband.device = "/dev/bus/usb";
            # services.airband.ports = [ "8000:8000" "8001:8001" ];
            # services.airband.volumes = [ "/opt/adsb/airband:/run/rtlsdr-airband" ];
          };
        })
      ];
    };
  };
}
