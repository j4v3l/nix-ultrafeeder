{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.airband;
in {
  options.services.airband = {
    meta = {
      maintainers = ["j4v3l"];
      description = "Run SDR-Enthusiasts docker-rtlsdrairband (ATC audio streaming)";
    };

    enable = lib.mkEnableOption "Run rtlsdr-airband + icecast container";

    backend = lib.mkOption {
      type = lib.types.enum ["docker" "podman"];
      default = "docker";
      description = "OCI backend used by `virtualisation.oci-containers`.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/sdr-enthusiasts/docker-rtlsdrairband";
      description = "rtlsdr-airband container image.";
    };

    imageFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional local image tarball for the airband container.";
    };

    tag = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "rtlsdr-airband image tag.";
    };

    device = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Host device to pass through (e.g., /dev/bus/usb for RTL-SDR).";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Environment variables passed to the airband container (RTLSDRAIRBAND_*, ICECAST_*, etc.).";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Environment files passed to the container (recommended for secrets/keys).";
    };

    volumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Bind mounts (e.g., /opt/adsb/airband:/run/rtlsdr-airband for custom configs or recordings).";
    };

    ports = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "8000:8000" # icecast web/audio
        "8001:8001" # prometheus stats if enabled
      ];
      description = "Port mappings for icecast/web/stats endpoints.";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional docker/podman CLI options (add extra --device entries, etc.).";
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

      containers.airband =
        {
          image = "${cfg.image}:${cfg.tag}";
          autoStart = true;
          inherit (cfg) environment environmentFiles volumes ports;
          extraOptions =
            (lib.optional (cfg.networkName != null) "--network=${cfg.networkName}")
            ++ cfg.extraOptions
            ++ lib.optionals (cfg.device != null) ["--device=${cfg.device}:${cfg.device}"];
        }
        // lib.optionalAttrs (cfg.imageFile != null) {inherit (cfg) imageFile;};
    };

    systemd.services.docker-airband = lib.mkIf (cfg.networkName != null) {
      serviceConfig = {
        Path = [pkgs.coreutils pkgs.docker pkgs.podman];
        ExecStartPre = [
          (pkgs.writeShellScript "ensure-airband-network" ''
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
