{
  config,
  lib,
  ...
}: let
  cfg = config.services.ultrafeeder;

  # Extract host ports from oci-containers "ports" entries like:
  # - "8080:80"
  # - "127.0.0.1:8080:80"
  # We only open firewall for simple leading host port mappings.
  hostTcpPorts = let
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
    lib.filter (x: x != null) (map toHostPort cfg.ports);

  # Create tmpfiles rules for host directories listed in volume mappings.
  # Supports entries like:
  # - "/opt/adsb/ultrafeeder/globe_history:/var/globe_history"
  # - "/opt/adsb/ultrafeeder/collectd:/var/lib/collectd:rw"
  volumeHostDirs = let
    hostPart = v: let
      parts = lib.splitString ":" v;
    in
      if parts == []
      then null
      else builtins.elemAt parts 0;
  in
    lib.unique (lib.filter (p: p != null && lib.hasPrefix "/" p) (map hostPart cfg.volumes));
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
  };

  config = lib.mkIf cfg.enable (let
    # Merge ULTRAFEEDER_CONFIG fragments (if configured) into the container env
    # without discarding user-provided env vars.
    ultrafeederEnvMerged = let
      base = cfg.environment.ULTRAFEEDER_CONFIG or null;
      mlathubFrags = map (i: "mlathub,${i.host},${toString i.port},${i.protocol}") cfg.mlatHubInputs;
      frags = cfg.ultrafeederConfigFragments ++ mlathubFrags;
      fragsStr = lib.concatStringsSep ";" frags;
      final =
        if frags == []
        then base
        else if base == null
        then fragsStr
        else "${base};${fragsStr}";
    in
      cfg.environment
      // lib.optionalAttrs (final != null) {ULTRAFEEDER_CONFIG = final;};
  in {
    virtualisation.oci-containers = {
      backend = lib.mkDefault cfg.backend;

      containers.ultrafeeder = {
        image = "${cfg.image}:${cfg.tag}";
        autoStart = true;
        environment = ultrafeederEnvMerged;
        inherit (cfg) environmentFiles volumes ports;
        extraOptions =
          cfg.extraOptions
          ++ lib.optionals (cfg.device != null) ["--device=${cfg.device}:${cfg.device}"];
      };
    };

    systemd.tmpfiles.rules = lib.mkIf cfg.createHostDirs (map (d: "d ${d} 0755 root root -") volumeHostDirs);

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall hostTcpPorts;
  });
}
