{
  pkgs,
  ultrafeederModulePath,
}:
pkgs.testers.nixosTest {
  name = "ultrafeeder-options";
  nodes.machine = {...}: {
    imports = [ultrafeederModulePath];
    services.ultrafeeder = {
      enable = true;
      backend = "docker";
      openFirewall = true;
      createHostDirs = true;
      image = "ultrafeeder-options-test";
      tag = "latest";
      environment = {
        TZ = "UTC";
        READSB_DEVICE_TYPE = "rtlsdr";
      };
      tar1090 = {
        enable = true;
        pageTitle = "Test Site";
        siteLat = "51.5";
        siteLon = "-0.1";
        siteName = "London";
        enableHeatmap = true;
        enableActualRange = false;
        disable = false;
      };
      imageFile = pkgs.dockerTools.buildImage {
        name = "ultrafeeder-options-test";
        tag = "latest";
        copyToRoot = pkgs.buildEnv {
          name = "ultrafeeder-options-root";
          paths = [pkgs.busybox];
        };
        config = {
          Cmd = ["sleep" "infinity"];
        };
      };
      volumes = [
        "/tmp/globe_history:/var/globe_history"
      ];
      device = "/dev/null";

      prometheus.enable = true;
      prometheus.port = "19273:9273";

      storage.timelapseDir = "/var/tmp/ultra-tl";
      storage.offlineMapsDir = "/var/tmp/ultra-offline";

      telemetry.mountDiskstats = true;
      # Skip thermal zone in the test to avoid creating a mountpoint on read-only /sys.
      telemetry.thermalZone = null;

      readsb = {
        autogain = true;
        gain = "autogain";
        ppm = 12;
        biastee = true;
        uat = true;
      };
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("docker-ultrafeeder.service")
    machine.wait_until_succeeds("docker inspect ultrafeeder --format '{{.State.Status}}' | grep running")

    # Env flags merged
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep PROMETHEUS_ENABLE=true")
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep AUTOGAIN=true")
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep READSB_GAIN=autogain")
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep READSB_PPM=12")
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep READSB_BIASTEE=true")
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep UAT_ENABLE=true")

    # TAR1090 environment variables
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep TAR1090_PAGETITLE=Test Site")
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep TAR1090_SITELAT=51.5")
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep TAR1090_SITELON=-0.1")
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep TAR1090_SITENAME=London")
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep TAR1090_ENABLE_HEATMAP=true")
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep TAR1090_ENABLE_ACTUALRANGE=false")
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep TAR1090_DISABLE=false")

    # Ports merged (host 19273 added)
    machine.succeed("docker inspect ultrafeeder --format '{{json .HostConfig.PortBindings}}' | grep 19273")

    # Volumes merged (timelapse + offline maps + diskstats + thermal) and tmpfiles excludes /proc,/sys
    machine.succeed("docker inspect ultrafeeder --format '{{json .HostConfig.Binds}}' | grep '/var/tmp/ultra-tl:/var/timelapse1090'")
    machine.succeed("docker inspect ultrafeeder --format '{{json .HostConfig.Binds}}' | grep '/var/tmp/ultra-offline:/usr/local/share/osm_tiles_offline'")
    machine.succeed("docker inspect ultrafeeder --format '{{json .HostConfig.Binds}}' | grep '/proc/diskstats:/proc/diskstats:ro'")

    # Host dirs should exist (created by tmpfiles) while /proc binds are excluded.
    machine.succeed("stat /var/tmp/ultra-tl")
    machine.succeed("stat /var/tmp/ultra-offline")
    machine.fail("grep '/proc/diskstats' /run/current-system/sw/lib/tmpfiles.d/*.conf")
  '';
}
