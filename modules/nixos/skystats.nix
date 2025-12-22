{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.skystats;

  hostTcpPorts = let
    toHostPort = p: let
      parts = lib.splitString ":" p;
    in
      if (builtins.length parts) < 2
      then null
      else let
        hostPort =
          if (builtins.length parts) == 2
          then builtins.elemAt parts 0
          else builtins.elemAt parts 1;
      in
        if lib.isInt (builtins.tryEval (lib.toInt hostPort)).value
        then lib.toInt hostPort
        else null;
  in
    lib.filter (x: x != null) (map toHostPort cfg.ports);

  volumeHostDirs = let
    hostPart = v: let
      parts = lib.splitString ":" v;
    in
      if parts == []
      then null
      else builtins.elemAt parts 0;
  in
    lib.unique (lib.filter (p: p != null && lib.hasPrefix "/" p) (map hostPart cfg.volumes));

  appEnv =
    {
      DB_HOST = cfg.database.host;
      DB_PORT = toString cfg.database.port;
      DB_USER = cfg.database.user;
      DB_NAME = cfg.database.name;
    }
    // lib.optionalAttrs (cfg.database.password != null) {DB_PASSWORD = cfg.database.password;}
    // lib.optionalAttrs (cfg.readsbAircraftJsonUrl != null) {
      READSB_AIRCRAFT_JSON = cfg.readsbAircraftJsonUrl;
    }
    // lib.optionalAttrs (cfg.app.lat != null) {LAT = cfg.app.lat;}
    // lib.optionalAttrs (cfg.app.lon != null) {LON = cfg.app.lon;}
    // lib.optionalAttrs (cfg.app.radiusKm != null) {RADIUS = toString cfg.app.radiusKm;}
    // lib.optionalAttrs (cfg.app.aboveRadiusKm != null) {ABOVE_RADIUS = toString cfg.app.aboveRadiusKm;}
    // lib.optionalAttrs (cfg.app.domesticCountryIso != null) {DOMESTIC_COUNTRY_ISO = cfg.app.domesticCountryIso;}
    // lib.optionalAttrs (cfg.app.logLevel != null) {LOG_LEVEL = cfg.app.logLevel;};

  dbEnv =
    {
      POSTGRES_USER = cfg.database.user;
      POSTGRES_DB = cfg.database.name;
    }
    // lib.optionalAttrs (cfg.database.password != null) {POSTGRES_PASSWORD = cfg.database.password;};
in {
  options.services.skystats = {
    meta = {
      maintainers = ["j4v3l"];
      description = "Run Skystats (web UI + daemon) with a PostgreSQL DB via oci-containers";
    };
    enable = lib.mkEnableOption "Run Skystats (web UI + daemon) with a PostgreSQL DB via oci-containers";

    backend = lib.mkOption {
      type = lib.types.enum ["docker" "podman"];
      default = "docker";
      description = "OCI backend used by `virtualisation.oci-containers`.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/tomcarman/skystats";
      description = "Skystats container image repository.";
    };

    tag = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Skystats image tag.";
    };

    imageFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional local image tarball for the Skystats container.";
    };

    dbImage = lib.mkOption {
      type = lib.types.str;
      default = "postgres";
      description = "PostgreSQL image repository.";
    };

    dbTag = lib.mkOption {
      type = lib.types.str;
      default = "17";
      description = "PostgreSQL image tag.";
    };

    dbImageFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional local image tarball for the Postgres companion container.";
    };

    readsbAircraftJsonUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://192.168.1.100:8080/data/aircraft.json";
      description = ''
        URL to `readsb`'s `aircraft.json` that Skystats will consume.
        This is typically served by `docker-adsb-ultrafeeder`'s web UI (tar1090/readsb).
      '';
    };

    app = {
      lat = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "51.5074";
        description = "Receiver latitude (string to preserve precision).";
      };

      lon = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "-0.1278";
        description = "Receiver longitude (string to preserve precision).";
      };

      radiusKm = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 1000;
        description = "Radius in km from your receiver to record aircraft.";
      };

      aboveRadiusKm = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 20;
        description = "Radius for the \"Above Timeline\" feature (Skystats docs note 20km).";
      };

      domesticCountryIso = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "GB";
        description = "ISO 2-letter country code used for domestic airport stats.";
      };

      logLevel = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "INFO";
        example = "DEBUG";
        description = "Skystats log level (e.g. TRACE, DEBUG, INFO, WARN, ERROR).";
      };
    };

    database = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "skystats-db";
        description = "Postgres host (defaults to the companion container name).";
      };

      port = lib.mkOption {
        type = lib.types.int;
        default = 5432;
        description = "Postgres port.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "skystats";
        description = "Postgres username.";
      };

      password = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Postgres password.
          Prefer injecting this via `services.skystats.dbEnvironmentFiles` / `services.skystats.environmentFiles`
          (e.g. generated by sops-nix templates) so the secret does not land in the Nix store.
        '';
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "skystats_db";
        description = "Postgres database name.";
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/skystats/postgres_data";
        description = "Host directory where postgres will persist its data.";
      };
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Extra environment variables passed to the Skystats container (merged with computed defaults).";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Environment files passed to the Skystats container (each file contains `KEY=VALUE` lines).
        Recommended for secrets injection (e.g. DB_PASSWORD via sops-nix templates) so values do not end up in the Nix store.
      '';
    };

    dbEnvironmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Environment files passed to the Postgres container (each file contains `KEY=VALUE` lines).
        Recommended for secrets injection (e.g. POSTGRES_PASSWORD via sops-nix templates).
      '';
    };

    ports = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["5173:80"];
      description = "Port mappings for the Skystats web UI.";
    };

    networkName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = let
        net = config.ultra.defaults.network or {};
        enabled = net.enable or false;
      in
        if enabled
        then net.name or "ultra-net"
        else null;
      description = "Optional container network to join (defaults to ultra.defaults.network.name when set).";
    };

    volumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra bind mounts for the Skystats container.";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional docker/podman CLI options for the Skystats container.";
    };

    dbExtraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional docker/podman CLI options for the Postgres container.";
    };

    createHostDirs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create host directories for volume mounts using systemd-tmpfiles.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the firewall for simple TCP host ports in `services.skystats.ports`.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = lib.mkDefault cfg.backend;

      containers = {
        "skystats-db" =
          {
            image = "${cfg.dbImage}:${cfg.dbTag}";
            autoStart = true;
            environment = dbEnv;
            environmentFiles = cfg.dbEnvironmentFiles;
            volumes = ["${cfg.database.dataDir}:/var/lib/postgresql/data"];
            extraOptions =
              (lib.optional (cfg.networkName != null) "--network=${cfg.networkName}")
              ++ cfg.dbExtraOptions;
          }
          // lib.optionalAttrs (cfg.dbImageFile != null) {imageFile = cfg.dbImageFile;};

        skystats =
          {
            image = "${cfg.image}:${cfg.tag}";
            autoStart = true;
            dependsOn = ["skystats-db"];
            inherit (cfg) ports environmentFiles volumes;
            environment = appEnv // cfg.environment;
            extraOptions =
              (lib.optional (cfg.networkName != null) "--network=${cfg.networkName}")
              ++ cfg.extraOptions;
          }
          // lib.optionalAttrs (cfg.imageFile != null) {inherit (cfg) imageFile;};
      };
    };

    systemd.services = lib.mkIf (cfg.networkName != null) {
      "docker-skystats-db".serviceConfig = {
        Path = [pkgs.coreutils pkgs.docker pkgs.podman];
        ExecStartPre = [
          (pkgs.writeShellScript "ensure-skystats-net" ''
            set -euo pipefail
            net="${cfg.networkName}"
            [ -z "$net" ] && exit 0
            tool=""
            if command -v docker >/dev/null 2>&1; then tool=docker; elif command -v podman >/dev/null 2>&1; then tool=podman; fi
            [ -z "$tool" ] && exit 0
            if ! "$tool" network inspect "$net" >/dev/null 2>&1; then
              "$tool" network create --driver "${config.ultra.defaults.network.driver or "bridge"}" "$net"
            fi
          '')
        ];
      };
      "docker-skystats".serviceConfig = {
        Path = [pkgs.coreutils pkgs.docker pkgs.podman];
        ExecStartPre = [
          (pkgs.writeShellScript "ensure-skystats-net" ''
            set -euo pipefail
            net="${cfg.networkName}"
            [ -z "$net" ] && exit 0
            tool=""
            if command -v docker >/dev/null 2>&1; then tool=docker; elif command -v podman >/dev/null 2>&1; then tool=podman; fi
            [ -z "$tool" ] && exit 0
            if ! "$tool" network inspect "$net" >/dev/null 2>&1; then
              "$tool" network create --driver "${config.ultra.defaults.network.driver or "bridge"}" "$net"
            fi
          '')
        ];
      };
    };

    systemd.tmpfiles.rules = lib.mkIf cfg.createHostDirs (
      ["d ${cfg.database.dataDir} 0755 root root -"]
      ++ (map (d: "d ${d} 0755 root root -") volumeHostDirs)
    );

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall hostTcpPorts;
  };
}
