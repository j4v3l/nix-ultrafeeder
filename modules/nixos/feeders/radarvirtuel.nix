{
  config,
  lib,
  ...
}: let
  cfg = config.services.adsbFeeders.radarvirtuel;
in {
  options.services.adsbFeeders.radarvirtuel = {
    meta = {
      maintainers = ["j4v3l"];
      description = "Run SDR-Enthusiasts RadarVirtuel feeder container";
    };
    enable = lib.mkEnableOption "Run RadarVirtuel feeder container";

    backend = lib.mkOption {
      type = lib.types.enum ["docker" "podman"];
      default = "docker";
      description = "OCI backend used by `virtualisation.oci-containers`.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/sdr-enthusiasts/docker-radarvirtuel";
      description = "RadarVirtuel feeder image repository.";
    };

    tag = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "RadarVirtuel feeder image tag.";
    };

    imageFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional local image tarball for the RadarVirtuel container.";
    };

    beastHost = lib.mkOption {
      type = lib.types.str;
      default = "ultrafeeder";
      description = "Hostname/IP of the BEAST source.";
    };

    beastPort = lib.mkOption {
      type = lib.types.int;
      default = 30005;
      description = "TCP port of the BEAST source.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Extra environment variables passed to the RadarVirtuel container.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Environment files passed to the RadarVirtuel container (recommended for secrets).";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional docker/podman CLI options for the RadarVirtuel container.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = lib.mkDefault cfg.backend;

      containers.radarvirtuel =
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
