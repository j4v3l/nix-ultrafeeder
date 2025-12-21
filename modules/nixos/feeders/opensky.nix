{
  config,
  lib,
  ...
}: let
  cfg = config.services.adsbFeeders.opensky;
in {
  options.services.adsbFeeders.opensky = {
    meta = {
      maintainers = ["j4v3l"];
      description = "Run SDR-Enthusiasts OpenSky Network feeder container";
    };
    enable = lib.mkEnableOption "Run OpenSky Network feeder container";

    backend = lib.mkOption {
      type = lib.types.enum ["docker" "podman"];
      default = "docker";
      description = "OCI backend used by `virtualisation.oci-containers`.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/sdr-enthusiasts/docker-opensky-network";
      description = "OpenSky Network feeder image repository.";
    };

    tag = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "OpenSky Network feeder image tag.";
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
      description = "Extra environment variables passed to the OpenSky Network container.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Environment files passed to the OpenSky Network container (recommended for secrets).";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional docker/podman CLI options for the OpenSky Network container.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = lib.mkDefault cfg.backend;

      containers.opensky = {
        image = "${cfg.image}:${cfg.tag}";
        autoStart = true;
        environment =
          {
            BEASTHOST = cfg.beastHost;
            BEASTPORT = toString cfg.beastPort;
          }
          // cfg.environment;
        inherit (cfg) environmentFiles extraOptions;
      };
    };
  };
}
