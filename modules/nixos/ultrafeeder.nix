{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.ultrafeeder;

  # Extract host ports from oci-containers "ports" entries like:
  # - "8080:80"
  # - "127.0.0.1:8080:80"
  # We only open firewall for simple leading host port mappings.
  hostTcpPortsFrom = ports: let
    toHostPort = p: let
      parts = lib.splitString ":" p;
      # "8080:80" -> [8080, 80]; "127.0.0.1:8080:80" -> [127.0.0.1, 8080, 80]
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
    lib.filter (x: x != null) (map toHostPort ports);

  # Create tmpfiles rules for host directories listed in volume mappings.
  # Supports entries like:
  # - "/opt/adsb/ultrafeeder/globe_history:/var/globe_history"
  # - "/opt/adsb/ultrafeeder/collectd:/var/lib/collectd:rw"
  volumeHostDirsFrom = volumes: let
    hostPart = v: let
      parts = lib.splitString ":" v;
    in
      if parts == []
      then null
      else builtins.elemAt parts 0;
  in
    lib.unique (lib.filter (p: p != null && lib.hasPrefix "/" p) (map hostPart volumes));
in {
  options.services.ultrafeeder = {
    meta = {
      maintainers = ["j4v3l"];
      description = "Run SDR-Enthusiasts Ultrafeeder in a container (via oci-containers)";
    };
    enable = lib.mkEnableOption "Run ADSB-Ultrafeeder in a container (via oci-containers)";

    backend = lib.mkOption {
      type = lib.types.enum ["docker" "podman"];
      default = "docker";
      description = "OCI backend used by `virtualisation.oci-containers`.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/sdr-enthusiasts/docker-adsb-ultrafeeder";
      description = "Container image repository.";
    };

    imageFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional OCI image tarball to load instead of pulling from a registry (useful for offline tests).";
    };

    tag = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Container image tag.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {
        TZ = "UTC";
        READSB_DEVICE_TYPE = "rtlsdr";
        READSB_DEVICE = "00000001";
      };
      description = "Environment variables passed to the container.";
    };

    ultrafeederConfigFragments = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [
        "mlat,in.adsb.lol,31090,uuid=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
        "mlathub,piaware,30105,beast_in"
      ];
      description = ''
        Extra `ULTRAFEEDER_CONFIG` fragments to append.

        If `services.ultrafeeder.environment.ULTRAFEEDER_CONFIG` is set, these fragments are appended with `;`.
        Otherwise, `ULTRAFEEDER_CONFIG` is created from these fragments.
      '';
    };

    mlatHubInputs = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule (_: {
          options = {
            host = lib.mkOption {
              type = lib.types.str;
              example = "piaware";
              description = "Hostname/container name where MLAT results are available.";
            };
            port = lib.mkOption {
              type = lib.types.int;
              example = 30105;
              description = "TCP port where MLAT results are available.";
            };
            protocol = lib.mkOption {
              type = lib.types.str;
              default = "beast_in";
              description = "Protocol for MLAT hub ingest (typically `beast_in`).";
            };
          };
        })
      );
      default = [];
      description = ''
        Convenience wrapper to ingest external MLAT results into Ultrafeeder via `ULTRAFEEDER_CONFIG=mlathub,...`.

        Example for PiAware:
          - host: `piaware`
          - port: `30105`
          - protocol: `beast_in`
      '';
    };

    prometheus = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Expose Prometheus metrics (telegraf) from the ultrafeeder image.";
      };

      port = lib.mkOption {
        type = lib.types.str;
        default = "9273:9273";
        description = "Port mapping for the Prometheus endpoint (only applied when enable = true).";
      };
    };

    storage = {
      timelapseDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/opt/adsb/ultrafeeder/timelapse1090";
        description = "Host directory for timelapse1090 data (adds volume if set).";
      };

      offlineMapsDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/usr/local/share/osm_tiles_offline";
        description = "Host directory containing offline map tiles (mounts to /usr/local/share/osm_tiles_offline).";
      };
    };

    telemetry = {
      mountDiskstats = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mount /proc/diskstats read-only for graphs1090 metrics.";
      };

      thermalZone = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/sys/class/thermal/thermal_zone0";
        description = "Host thermal zone to pass through for CPU temp metrics (read-only).";
      };
    };

    readsb = {
      autogain = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable autogain (sets AUTOGAIN=true).";
      };

      gain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "autogain";
        description = "Explicit READSB_GAIN value (e.g., autogain or numeric).";
      };

      ppm = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 1;
        description = "READSB_PPM correction.";
      };

      biastee = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable READSB_BIASTEE for RTL-SDR bias tee.";
      };

      uat = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable UAT/978 (sets UAT_ENABLE=true).";
      };
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Environment files passed to the container (each file contains `KEY=VALUE` lines).
        Recommended for secrets injection (e.g. via sops-nix templates) so values do not end up in the Nix store.
      '';
    };

    volumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [
        "/opt/adsb/ultrafeeder/globe_history:/var/globe_history"
        "/opt/adsb/ultrafeeder/collectd:/var/lib/collectd"
      ];
      description = "Bind mounts passed to the container.";
    };

    ports = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # tar1090 / web UI (if enabled by env vars)
        "8080:80"
        # readsb ports (common defaults; adjust to taste)
        "30003:30003"
        "30005:30005"
        "30104:30104"
      ];
      description = "Port mappings passed to the container (oci-containers format).";
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

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [
        "--network=host"
        "--privileged"
      ];
      description = "Additional docker/podman CLI options for the container.";
    };

    device = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/dev/bus/usb";
      description = "Optional host device path to pass through (added as `--device=...`).";
    };

    createHostDirs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create host directories for volume mounts using systemd-tmpfiles.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the firewall for simple TCP host ports in `services.ultrafeeder.ports`.";
    };
    # GPSD integration
    gpsd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable gpsd integration for dynamic receiver location.";
      };
      host = lib.mkOption {
        type = lib.types.str;
        default = "host.docker.internal";
        example = "host.docker.internal";
        description = "Host/IP where gpsd is running (default: host.docker.internal for Docker).";
      };
      port = lib.mkOption {
        type = lib.types.int;
        default = 2947;
        example = 2947;
        description = "Port where gpsd is listening (default: 2947).";
      };
      minDistance = lib.mkOption {
        type = lib.types.int;
        default = 20;
        example = 20;
        description = "GPSD_MIN_DISTANCE: Distance in meters before location is considered changed.";
      };
      mlatWait = lib.mkOption {
        type = lib.types.int;
        default = 90;
        example = 90;
        description = "GPSD_MLAT_WAIT: Wait period in seconds before mlat restarts after movement.";
      };
      checkInterval = lib.mkOption {
        type = lib.types.int;
        default = 30;
        example = 30;
        description = "GPSD_CHECK_INTERVAL: How often to check for updated location (seconds).";
      };
    };
  };

  config = lib.mkIf cfg.enable (let
    # Merge ULTRAFEEDER_CONFIG fragments (if configured) into the container env
    # without discarding user-provided env vars.
    # Compose ULTRAFEEDER_CONFIG fragments, including gpsd if enabled
    gpsdFrag =
      if cfg.gpsd.enable
      then ["gpsd,${cfg.gpsd.host},${toString cfg.gpsd.port}"]
      else [];
    mlathubFrags = map (i: "mlathub,${i.host},${toString i.port},${i.protocol}") cfg.mlatHubInputs;
    allFrags = cfg.ultrafeederConfigFragments ++ mlathubFrags ++ gpsdFrag;
    base = cfg.environment.ULTRAFEEDER_CONFIG or null;
    fragsStr = lib.concatStringsSep ";" allFrags;
    final =
      if allFrags == []
      then base
      else if base == null
      then fragsStr
      else "${base};${fragsStr}";
    gpsdEnv = lib.optionalAttrs cfg.gpsd.enable {
      GPSD_MIN_DISTANCE = toString cfg.gpsd.minDistance;
      GPSD_MLAT_WAIT = toString cfg.gpsd.mlatWait;
      GPSD_CHECK_INTERVAL = toString cfg.gpsd.checkInterval;
    };
    ultrafeederEnvMerged =
      cfg.environment
      // lib.optionalAttrs (final != null) {ULTRAFEEDER_CONFIG = final;}
      // gpsdEnv;

    telemetryEnv =
      lib.optionalAttrs cfg.prometheus.enable {PROMETHEUS_ENABLE = "true";}
      // lib.optionalAttrs cfg.readsb.autogain {AUTOGAIN = "true";}
      // lib.optionalAttrs (cfg.readsb.gain != null) {READSB_GAIN = cfg.readsb.gain;}
      // lib.optionalAttrs (cfg.readsb.ppm != null) {READSB_PPM = toString cfg.readsb.ppm;}
      // lib.optionalAttrs cfg.readsb.biastee {READSB_BIASTEE = "true";}
      // lib.optionalAttrs cfg.readsb.uat {UAT_ENABLE = "true";};

    extraPorts =
      lib.optional cfg.prometheus.enable cfg.prometheus.port;

    extraVolumes =
      lib.optional (cfg.storage.timelapseDir != null) "${cfg.storage.timelapseDir}:/var/timelapse1090"
      ++ lib.optional (cfg.storage.offlineMapsDir != null)
      "${cfg.storage.offlineMapsDir}:/usr/local/share/osm_tiles_offline"
      ++ lib.optional cfg.telemetry.mountDiskstats "/proc/diskstats:/proc/diskstats:ro"
      ++ lib.optional (cfg.telemetry.thermalZone != null) "${cfg.telemetry.thermalZone}:/sys/class/thermal/thermal_zone0:ro";

    portsMerged = cfg.ports ++ extraPorts;
    volumesMerged = cfg.volumes ++ extraVolumes;
    hostTcpPorts = hostTcpPortsFrom portsMerged;
    volumeHostDirs = volumeHostDirsFrom volumesMerged;
    volumeHostDirsUser = lib.filter (p: !(lib.hasPrefix "/proc/" p || lib.hasPrefix "/sys/" p)) volumeHostDirs;
    networkExtra = lib.optional (cfg.networkName != null) "--network=${cfg.networkName}";
    ensureNetworkScript = pkgs.writeShellScript "ensure-ultrafeeder-network" ''
      set -euo pipefail
      net="${cfg.networkName}"
      [ -z "$net" ] && exit 0

      tool=""
      if command -v docker >/dev/null 2>&1; then
        tool=docker
      elif command -v podman >/dev/null 2>&1; then
        tool=podman
      fi
      [ -z "$tool" ] && exit 0

      if ! "$tool" network inspect "$net" >/dev/null 2>&1; then
        "$tool" network create --driver "${config.ultra.defaults.network.driver or "bridge"}" "$net"
      fi
    '';
  in {
    virtualisation.oci-containers = {
      backend = lib.mkDefault cfg.backend;

      containers.ultrafeeder =
        {
          image = "${cfg.image}:${cfg.tag}";
          autoStart = true;
          environment = ultrafeederEnvMerged // telemetryEnv;
          inherit (cfg) environmentFiles;
          volumes = volumesMerged;
          ports = portsMerged;
          extraOptions =
            networkExtra
            ++ cfg.extraOptions
            ++ lib.optionals (cfg.device != null) ["--device=${cfg.device}:${cfg.device}"];
        }
        // lib.optionalAttrs (cfg.imageFile != null) {inherit (cfg) imageFile;};
    };

    systemd.services.docker-ultrafeeder = lib.mkIf (cfg.networkName != null) {
      serviceConfig = {
        Path = [pkgs.coreutils pkgs.docker pkgs.podman];
        ExecStartPre = [ensureNetworkScript];
      };
    };

    systemd.tmpfiles.rules = lib.mkIf cfg.createHostDirs (map (d: "d ${d} 0755 root root -") volumeHostDirsUser);

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall hostTcpPorts;
  });
}
