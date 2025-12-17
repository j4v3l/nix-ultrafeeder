{
  config,
  lib,
  ...
}: let
  cfg = config.services.adsbFeeders.flightradar24;
in {
  options.services.adsbFeeders.flightradar24 = {
    enable = lib.mkEnableOption "Run SDR-Enthusiasts FlightRadar24 feeder container";

    backend = lib.mkOption {
      type = lib.types.enum ["docker" "podman"];
      default = "docker";
      description = "OCI backend used by `virtualisation.oci-containers`.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/sdr-enthusiasts/docker-flightradar24";
      description = "FlightRadar24 container image repository.";
    };

    tag = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "FlightRadar24 image tag.";
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
      description = "Extra environment variables passed to the FlightRadar24 container.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Environment files passed to the FlightRadar24 container (recommended for secrets).";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional docker/podman CLI options for the FlightRadar24 container.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = lib.mkDefault cfg.backend;

      containers.flightradar24 = {
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
