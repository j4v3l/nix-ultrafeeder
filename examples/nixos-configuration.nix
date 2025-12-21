_: {
  # Example usage (import the module from this flake in your system flake):
  #
  #   inputs.nix-ultrafeeder.url = "path:/path/to/nix-ultrafeeder";
  #   outputs = { self, nixpkgs, nix-ultrafeeder, ... }: {
  #     nixosConfigurations.myHost = nixpkgs.lib.nixosSystem {
  #       modules = [
  #         nix-ultrafeeder.nixosModules.ultrafeeder
  #         ./configuration.nix
  #       ];
  #     };
  #   };

  services.ultrafeeder = {
    enable = true;

    # If you use podman:
    # backend = "podman";

    environment = {
      TZ = "UTC";

      # Minimal-ish defaults; tune these per upstream docs.
      READSB_DEVICE_TYPE = "rtlsdr";

      # Example: identify the dongle by serial (or omit and let readsb pick the first).
      # READSB_DEVICE = "00000001";

      # If you don't want mapping/UI:
      # TAR1090_DISABLE = "true";
      # MLATHUB_DISABLE = "true";
    };

    volumes = [
      "/opt/adsb/ultrafeeder/globe_history:/var/globe_history"
      "/opt/adsb/ultrafeeder/collectd:/var/lib/collectd"
    ];

    # USB access is platform-specific; you may prefer a more specific device mapping.
    device = "/dev/bus/usb";

    # openFirewall = true;
  };

  services.skystats = {
    enable = true;

    # Skystats consumes readsb's aircraft.json. Use the HOST/IP where ultrafeeder publishes it.
    # If ultrafeeder is on the same host and you publish `8080:80`, this is often:
    #   http://<host-ip>:8080/data/aircraft.json
    readsbAircraftJsonUrl = "http://192.168.1.100:8080/data/aircraft.json";

    app = {
      lat = "51.5074";
      lon = "-0.1278";
      radiusKm = 1000;
      aboveRadiusKm = 20;
      domesticCountryIso = "GB";
      logLevel = "INFO";
    };

    database = {
      # password = "change-me"; # Prefer sops/age injection below
      # dataDir = "/var/lib/skystats/postgres_data";
    };

    # openFirewall = true; # opens 5173/tcp by default
  };

  # Example sops/age secrets wiring (recommended).
  # This requires importing `nixosModules.ultra` from this flake (it includes sops-nix).
  #
  # ultra.sops.ageKeyFile = "/var/lib/sops-nix/key.txt";
  # ultra.sops.defaultSopsFile = "/etc/nixos/secrets.yaml";
  #
  # services.skystats.sops = {
  #   enable = true;
  #   sopsFile = "/etc/nixos/secrets.yaml";
  #   # Defaults map DB_PASSWORD/POSTGRES_PASSWORD -> "skystats_db_password"
  # };
  #
  # services.ultrafeeder.sops = {
  #   enable = true;
  #   sopsFile = "/etc/nixos/secrets.yaml";
  #   envToSecret = {
  #     FEEDER_KEY = "ultrafeeder_feeder_key";
  #   };
  # };

  # Optional feeder containers (FlightAware/PiAware, FR24, PlaneFinder, AirNav Radar)
  #
  # services.adsbFeeders.piaware.enable = true;
  # services.adsbFeeders.flightradar24.enable = true;
  # services.adsbFeeders.planefinder.enable = true;
  # services.adsbFeeders.airnavradar.enable = true;
  #
  # If you want secrets via sops-nix templates (matches keys in `secrets/example.secrets.yaml`):
  #
  # services.adsbFeeders.piaware.sops = {
  #   enable = true;
  #   sopsFile = "/etc/nixos/secrets.yaml";
  #   # defaults: FEEDER_ID -> "piaware_FEEDER_ID"
  # };
  #
  # services.adsbFeeders.flightradar24.sops = {
  #   enable = true;
  #   sopsFile = "/etc/nixos/secrets.yaml";
  #   # defaults: FR24KEY -> "flightradar24_FR24KEY", FR24KEY_UAT -> "flightradar24_FR24KEY_UAT"
  # };
  #
  # services.adsbFeeders.planefinder.sops = {
  #   enable = true;
  #   sopsFile = "/etc/nixos/secrets.yaml";
  #   # defaults: SHARECODE -> "planefinder_SHARECODE"
  # };
  #
  # services.adsbFeeders.airnavradar.sops = {
  #   enable = true;
  #   sopsFile = "/etc/nixos/secrets.yaml";
  #   # defaults: SHARING_KEY -> "airnavradar_SHARING_KEY"
  # };

  # Logical MLAT support example (PiAware MLAT results displayed in Ultrafeeder):
  #
  # services.adsbFeeders.piaware = {
  #   enable = true;
  #   allowMlat = true;
  #   # The MLAT results port inside the container is typically 30105:
  #   # mlatResults.port = 30105;
  # };
  #
  # services.ultrafeeder.mlatHubInputs = [
  #   { host = "piaware"; port = 30105; protocol = "beast_in"; }
  # ];

  # Optional: auto-pull images on a schedule and restart containers if digests change.
  #
  # services.containerAutoUpdate = {
  #   enable = true;
  #   backend = "docker"; # or "podman"
  #   onCalendar = "*-*-* 03:00:00"; # daily at 03:00
  #   # images/units default to the enabled modules above; override if needed:
  #   # images = [ "ghcr.io/sdr-enthusiasts/docker-adsb-ultrafeeder:latest" ];
  #   # units = [ "docker-ultrafeeder.service" "docker-skystats.service" ];
  # };

  # Optional: metrics, storage, and readsb tuning for ultrafeeder
  #
  # services.ultrafeeder.prometheus.enable = false; # set true to expose 9273
  # services.ultrafeeder.prometheus.port = "9273:9273";
  # services.ultrafeeder.storage.timelapseDir = "/opt/adsb/ultrafeeder/timelapse1090";
  # services.ultrafeeder.storage.offlineMapsDir = "/usr/local/share/osm_tiles_offline";
  # services.ultrafeeder.telemetry.mountDiskstats = true;
  # services.ultrafeeder.telemetry.thermalZone = "/sys/class/thermal/thermal_zone0";
  # services.ultrafeeder.readsb = {
  #   autogain = true;
  #   gain = "autogain";
  #   ppm = 1;
  #   biastee = true;
  #   uat = true; # enable UAT/978
  # };
}
