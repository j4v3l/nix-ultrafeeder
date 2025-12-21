{
  config,
  lib,
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
          inherit (cfg) environmentFiles extraOptions;
        }
        // lib.optionalAttrs (cfg.imageFile != null) {inherit (cfg) imageFile;};
    };
  };
}
