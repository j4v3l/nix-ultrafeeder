{
  config,
  lib,
  ...
}: let
  cfg = config.services.adsbFeeders.planefinder;
in {
  options.services.adsbFeeders.planefinder = {
    meta = {
      maintainers = ["j4v3l"];
      description = "Run SDR-Enthusiasts PlaneFinder feeder container";
    };
    enable = lib.mkEnableOption "Run SDR-Enthusiasts PlaneFinder feeder container";

    backend = lib.mkOption {
      type = lib.types.enum ["docker" "podman"];
      default = "docker";
      description = "OCI backend used by `virtualisation.oci-containers`.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/sdr-enthusiasts/docker-planefinder";
      description = "PlaneFinder container image repository.";
    };

    tag = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "PlaneFinder image tag.";
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
      description = "Extra environment variables passed to the PlaneFinder container.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Environment files passed to the PlaneFinder container (recommended for secrets).";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional docker/podman CLI options for the PlaneFinder container.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = lib.mkDefault cfg.backend;

      containers.planefinder = {
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
