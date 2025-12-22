{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.ultra.defaults;
in {
  options.ultra.defaults = {
    network = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to create and use a shared bridge network for all ultrafeeder-related containers.";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "ultra-net";
        description = "Name of the shared container network that ultrafeeder, feeders, and companions should join.";
      };
      driver = lib.mkOption {
        type = lib.types.str;
        default = "bridge";
        description = "Driver to use for the shared container network.";
      };
    };

    ultrafeeder = {
      backend = lib.mkOption {
        type = lib.types.enum ["docker" "podman"];
        default = "docker";
        description = "Default container backend for ultrafeeder.";
      };
      image = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/sdr-enthusiasts/docker-adsb-ultrafeeder";
        description = "Default ultrafeeder image.";
      };
      tag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Default ultrafeeder tag.";
      };
      device = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default device passthrough for ultrafeeder (e.g., /dev/bus/usb).";
      };
      ports = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "8080:80"
          "30003:30003"
          "30005:30005"
          "30104:30104"
        ];
        description = "Default ultrafeeder ports.";
      };
      volumes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Default ultrafeeder volumes.";
      };
      prometheusPort = lib.mkOption {
        type = lib.types.str;
        default = "9273:9273";
        description = "Default Prometheus port mapping when enabled.";
      };
    };

    airband = {
      backend = lib.mkOption {
        type = lib.types.enum ["docker" "podman"];
        default = "docker";
        description = "Default container backend for airband.";
      };
      image = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/sdr-enthusiasts/docker-rtlsdrairband";
        description = "Default airband image.";
      };
      tag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Default airband image tag.";
      };
      device = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default device passthrough for airband (e.g., /dev/bus/usb).";
      };
      ports = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "8000:8000"
          "8001:8001"
        ];
        description = "Default airband ports (icecast/web/stats).";
      };
      volumes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Default airband volumes (e.g., /opt/adsb/airband:/run/rtlsdr-airband).";
      };
    };

    skystats = {
      image = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/tomcarman/skystats";
        description = "Default skystats image.";
      };
      tag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Default skystats tag.";
      };
      dbImage = lib.mkOption {
        type = lib.types.str;
        default = "postgres";
        description = "Default skystats Postgres image.";
      };
      dbTag = lib.mkOption {
        type = lib.types.str;
        default = "17";
        description = "Default skystats Postgres tag.";
      };
    };

    feeders = {
      backend = lib.mkOption {
        type = lib.types.enum ["docker" "podman"];
        default = "docker";
        description = "Default container backend for feeder containers.";
      };
      piawareImage = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/sdr-enthusiasts/docker-piaware";
        description = "Default PiAware image.";
      };
      flightradar24Image = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/sdr-enthusiasts/docker-flightradar24";
        description = "Default FlightRadar24 image.";
      };
      planefinderImage = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/sdr-enthusiasts/docker-planefinder";
        description = "Default PlaneFinder image.";
      };
      airnavradarImage = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/sdr-enthusiasts/docker-airnavradar";
        description = "Default AirNav Radar image.";
      };
      adsbhubImage = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/sdr-enthusiasts/docker-adsbhub";
        description = "Default ADSBHub feeder image.";
      };
      openskyImage = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/sdr-enthusiasts/docker-opensky-network";
        description = "Default OpenSky Network feeder image.";
      };
      radarvirtuelImage = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/sdr-enthusiasts/docker-radarvirtuel";
        description = "Default RadarVirtuel feeder image.";
      };
      radar1090ukImage = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/sdr-enthusiasts/docker-radar-uk";
        description = "Default Radar1090 UK feeder image.";
      };
      feederTag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Default tag for feeder images.";
      };
    };
  };

  config = {
    # Ensure the shared network exists before containers start (docker/podman).
    systemd.services."ultra-network-${cfg.network.name}" = lib.mkIf cfg.network.enable {
      description = "Ensure OCI network ${cfg.network.name} exists";
      wantedBy = ["docker-containers.target"];
      before = ["docker-containers.target"];
      after = ["docker.service" "podman.service"];
      path = [pkgs.coreutils pkgs.docker pkgs.podman];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "ensure-ultra-network" ''
          set -euo pipefail
          if command -v docker >/dev/null 2>&1; then
            tool=docker
          elif command -v podman >/dev/null 2>&1; then
            tool=podman
          else
            echo "Neither docker nor podman found on PATH" >&2
            exit 1
          fi

          if ! "$tool" network inspect ${cfg.network.name} >/dev/null 2>&1; then
            "$tool" network create --driver ${cfg.network.driver} ${cfg.network.name}
          fi
        '';
      };
    };

    services = {
      ultrafeeder = {
        backend = lib.mkDefault cfg.ultrafeeder.backend;
        image = lib.mkDefault cfg.ultrafeeder.image;
        tag = lib.mkDefault cfg.ultrafeeder.tag;
        device = lib.mkDefault cfg.ultrafeeder.device;
        ports = lib.mkDefault cfg.ultrafeeder.ports;
        volumes = lib.mkDefault cfg.ultrafeeder.volumes;
        prometheus.port = lib.mkDefault cfg.ultrafeeder.prometheusPort;
      };

      airband = {
        backend = lib.mkDefault cfg.airband.backend;
        image = lib.mkDefault cfg.airband.image;
        tag = lib.mkDefault cfg.airband.tag;
        device = lib.mkDefault cfg.airband.device;
        ports = lib.mkDefault cfg.airband.ports;
        volumes = lib.mkDefault cfg.airband.volumes;
      };

      skystats = {
        image = lib.mkDefault cfg.skystats.image;
        tag = lib.mkDefault cfg.skystats.tag;
        dbImage = lib.mkDefault cfg.skystats.dbImage;
        dbTag = lib.mkDefault cfg.skystats.dbTag;
      };

      adsbFeeders = {
        piaware = {
          backend = lib.mkDefault cfg.feeders.backend;
          image = lib.mkDefault cfg.feeders.piawareImage;
          tag = lib.mkDefault cfg.feeders.feederTag;
        };
        flightradar24 = {
          backend = lib.mkDefault cfg.feeders.backend;
          image = lib.mkDefault cfg.feeders.flightradar24Image;
          tag = lib.mkDefault cfg.feeders.feederTag;
        };
        planefinder = {
          backend = lib.mkDefault cfg.feeders.backend;
          image = lib.mkDefault cfg.feeders.planefinderImage;
          tag = lib.mkDefault cfg.feeders.feederTag;
        };
        airnavradar = {
          backend = lib.mkDefault cfg.feeders.backend;
          image = lib.mkDefault cfg.feeders.airnavradarImage;
          tag = lib.mkDefault cfg.feeders.feederTag;
        };
        adsbhub = {
          backend = lib.mkDefault cfg.feeders.backend;
          image = lib.mkDefault cfg.feeders.adsbhubImage;
          tag = lib.mkDefault cfg.feeders.feederTag;
        };
        opensky = {
          backend = lib.mkDefault cfg.feeders.backend;
          image = lib.mkDefault cfg.feeders.openskyImage;
          tag = lib.mkDefault cfg.feeders.feederTag;
        };
        radarvirtuel = {
          backend = lib.mkDefault cfg.feeders.backend;
          image = lib.mkDefault cfg.feeders.radarvirtuelImage;
          tag = lib.mkDefault cfg.feeders.feederTag;
        };
        radar1090uk = {
          backend = lib.mkDefault cfg.feeders.backend;
          image = lib.mkDefault cfg.feeders.radar1090ukImage;
          tag = lib.mkDefault cfg.feeders.feederTag;
        };
      };
    };
  };
}
