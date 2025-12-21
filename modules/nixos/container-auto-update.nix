{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.containerAutoUpdate;

  ufCfg = config.services.ultrafeeder;
  ssCfg = config.services.skystats;
  piawareCfg = config.services.adsbFeeders.piaware;
  fr24Cfg = config.services.adsbFeeders.flightradar24;
  pfCfg = config.services.adsbFeeders.planefinder;
  anCfg = config.services.adsbFeeders.airnavradar;

  defaultImages =
    lib.optional ufCfg.enable "${ufCfg.image}:${ufCfg.tag}"
    ++ lib.optionals ssCfg.enable [
      "${ssCfg.image}:${ssCfg.tag}"
      "${ssCfg.dbImage}:${ssCfg.dbTag}"
    ]
    ++ lib.optional piawareCfg.enable "${piawareCfg.image}:${piawareCfg.tag}"
    ++ lib.optional fr24Cfg.enable "${fr24Cfg.image}:${fr24Cfg.tag}"
    ++ lib.optional pfCfg.enable "${pfCfg.image}:${pfCfg.tag}"
    ++ lib.optional anCfg.enable "${anCfg.image}:${anCfg.tag}";

  unitPrefix =
    if cfg.backend == "podman"
    then "podman"
    else "docker";

  defaultUnits =
    lib.optional ufCfg.enable "${unitPrefix}-ultrafeeder.service"
    ++ lib.optionals ssCfg.enable [
      "${unitPrefix}-skystats.service"
      "${unitPrefix}-skystats-db.service"
    ]
    ++ lib.optional piawareCfg.enable "${unitPrefix}-piaware.service"
    ++ lib.optional fr24Cfg.enable "${unitPrefix}-flightradar24.service"
    ++ lib.optional pfCfg.enable "${unitPrefix}-planefinder.service"
    ++ lib.optional anCfg.enable "${unitPrefix}-airnavradar.service";

  backendPkg =
    if cfg.backend == "podman"
    then pkgs.podman
    else pkgs.docker;

  updaterScript = pkgs.writeShellScript "container-auto-update" ''
    set -euo pipefail

    backend=${lib.escapeShellArg cfg.backend}
    images=(
      ${lib.concatStringsSep "\n      " (map lib.escapeShellArg cfg.images)}
    )
    units=(
      ${lib.concatStringsSep "\n      " (map lib.escapeShellArg cfg.units)}
    )

    if [ "''${#images[@]}" -eq 0 ]; then
      echo "container-auto-update: no images configured; nothing to do"
      exit 0
    fi

    changed=0
    for img in "''${images[@]}"; do
      before="$(''${backend} image inspect --format '{{.Id}}' "$img" 2>/dev/null || true)"
      ''${backend} pull "$img" || true
      after="$(''${backend} image inspect --format '{{.Id}}' "$img" 2>/dev/null || true)"
      if [ -n "$after" ] && [ "$before" != "$after" ]; then
        echo "container-auto-update: image changed -> $img"
        changed=1
      fi
    done

    if [ "$changed" -eq 0 ]; then
      echo "container-auto-update: no changes detected"
      exit 0
    fi

    if [ "''${#units[@]}" -eq 0 ]; then
      echo "container-auto-update: no units listed; skipping restarts"
      exit 0
    fi

    for unit in "''${units[@]}"; do
      systemctl try-restart "$unit" || true
    done
  '';
in {
  options.services.containerAutoUpdate = {
    enable = lib.mkEnableOption "Auto-pull container images and restart units when digests change";

    backend = lib.mkOption {
      type = lib.types.enum ["docker" "podman"];
      default = "docker";
      description = "Which OCI backend to use for pulls and restarts.";
    };

    images = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultImages;
      defaultText = "Images from enabled ultrafeeder/skystats/feeder modules";
      example = ["ghcr.io/sdr-enthusiasts/docker-adsb-ultrafeeder:latest"];
      description = "Images to pull and watch for digest changes.";
    };

    units = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultUnits;
      defaultText = "Container units matching enabled services (docker-*.service / podman-*.service)";
      example = ["docker-ultrafeeder.service" "docker-skystats.service"];
      description = "Systemd units to restart when any image digest changes.";
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      example = "*-*-* 03:00:00";
      description = "Systemd OnCalendar expression controlling how often updates run.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.container-auto-update = {
      description = "Container image auto-update (pull + restart on digest change)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = updaterScript;
      };
      path = [backendPkg pkgs.coreutils];
    };

    systemd.timers.container-auto-update = {
      description = "Timer for container image auto-update";
      wantedBy = ["timers.target"];
      timerConfig.OnCalendar = cfg.onCalendar;
    };
  };
}
