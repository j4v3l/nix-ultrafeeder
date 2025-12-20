{
  config,
  lib,
  ...
}: let
  cfg = config.services.adsbFeeders.piaware;
in {
  options.services.adsbFeeders.piaware = {
    meta = {
      maintainers = ["j4v3l"];
      description = "Run SDR-Enthusiasts PiAware (FlightAware) feeder container";
    };
    enable = lib.mkEnableOption "Run SDR-Enthusiasts PiAware (FlightAware) feeder container";

    backend = lib.mkOption {
      type = lib.types.enum ["docker" "podman"];
      default = "docker";
      description = "OCI backend used by `virtualisation.oci-containers`.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/sdr-enthusiasts/docker-piaware";
      description = "PiAware container image repository.";
    };

    tag = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "PiAware image tag.";
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

    allowMlat = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable MLAT in the PiAware feeder container (sets `ALLOW_MLAT=true`).";
    };

    mlatResults = {
      port = lib.mkOption {
        type = lib.types.int;
        default = 30105;
        description = "Port inside the PiAware container where MLAT results are exposed (used by Ultrafeeder mlathub ingest).";
      };

      pushToUltrafeeder = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Push PiAware MLAT results to an external BEAST ingest (e.g. Ultrafeeder's MLATHUB_BEAST_IN_PORT, default 31004).
            This is an alternative to Ultrafeeder pulling results via `mlathub,piaware,30105,beast_in`.
          '';
        };

        beastHost = lib.mkOption {
          type = lib.types.str;
          default = "ultrafeeder";
          description = "Host to push MLAT results to (e.g. ultrafeeder).";
        };

        beastPort = lib.mkOption {
          type = lib.types.int;
          default = 31004;
          description = "Port to push MLAT results to (e.g. ultrafeeder's MLATHUB_BEAST_IN_PORT, default 31004).";
        };
      };
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Extra environment variables passed to the PiAware container.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Environment files passed to the PiAware container (recommended for secrets).";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional docker/podman CLI options for the PiAware container.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = lib.mkDefault cfg.backend;

      containers.piaware = {
        image = "${cfg.image}:${cfg.tag}";
        autoStart = true;
        environment =
          {
            # Most SDR-E feeders accept BEASTHOST/BEASTPORT to read data from ultrafeeder.
            BEASTHOST = cfg.beastHost;
            BEASTPORT = toString cfg.beastPort;
          }
          // lib.optionalAttrs cfg.allowMlat {ALLOW_MLAT = "true";}
          // lib.optionalAttrs cfg.mlatResults.pushToUltrafeeder.enable {
            MLAT_RESULTS_BEASTHOST = cfg.mlatResults.pushToUltrafeeder.beastHost;
            MLAT_RESULTS_BEASTPORT = toString cfg.mlatResults.pushToUltrafeeder.beastPort;
          }
          // cfg.environment;
        inherit (cfg) environmentFiles extraOptions;
      };
    };
  };
}
