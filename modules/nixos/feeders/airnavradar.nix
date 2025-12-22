{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.adsbFeeders.airnavradar;
in {
  options.services.adsbFeeders.airnavradar = {
    meta = {
      maintainers = ["j4v3l"];
      description = "Run SDR-Enthusiasts AirNav Radar feeder container";
    };
    enable = lib.mkEnableOption "Run SDR-Enthusiasts AirNav Radar feeder container";

    backend = lib.mkOption {
      type = lib.types.enum ["docker" "podman"];
      default = "docker";
      description = "OCI backend used by `virtualisation.oci-containers`.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/sdr-enthusiasts/docker-airnavradar";
      description = "AirNav Radar container image repository.";
    };

    tag = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "AirNav Radar image tag.";
    };

    imageFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional local image tarball for the AirNav Radar container.";
    };

    beastHost = lib.mkOption {
      type = lib.types.str;
      default = "ultrafeeder";
      description = "Hostname/IP of the BEAST source (typically the ultrafeeder container name).";
    };

    beastPort = lib.mkOption {
      type = lib.types.int;
      default = 30005;
      description = "TCP port of the BEAST source (typically ultrafeeder's 30005).";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Extra environment variables passed to the AirNav Radar container.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Environment files passed to the AirNav Radar container (recommended for secrets).";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional docker/podman CLI options for the AirNav Radar container.";
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
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = lib.mkDefault cfg.backend;

      containers.airnavradar =
        {
          image = "${cfg.image}:${cfg.tag}";
          autoStart = true;
          environment =
            {
              BEASTHOST = cfg.beastHost;
              BEASTPORT = toString cfg.beastPort;
            }
            // cfg.environment;
          inherit (cfg) environmentFiles;
          extraOptions =
            (lib.optional (cfg.networkName != null) "--network=${cfg.networkName}")
            ++ cfg.extraOptions;
        }
        // lib.optionalAttrs (cfg.imageFile != null) {inherit (cfg) imageFile;};
    };

    systemd.services.docker-airnavradar = lib.mkIf (cfg.networkName != null) {
      serviceConfig = {
        Path = [pkgs.coreutils pkgs.docker pkgs.podman];
        ExecStartPre = [
          (pkgs.writeShellScript "ensure-airnavradar-net" ''
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
  };
}
