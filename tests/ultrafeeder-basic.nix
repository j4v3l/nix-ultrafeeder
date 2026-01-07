{
  pkgs,
  ultrafeederModulePath,
}:
pkgs.testers.nixosTest {
  name = "ultrafeeder-basic";
  nodes.machine = {...}: {
    imports = [ultrafeederModulePath];
    services.ultrafeeder = {
      enable = true;
      backend = "docker";
      image = "ultrafeeder-test";
      tag = "latest";
      environment = {
        TZ = "UTC";
        READSB_DEVICE_TYPE = "rtlsdr";
      };
      gpsd = {
        enable = true;
        host = "host.docker.internal";
        port = 2947;
        minDistance = 15;
        mlatWait = 60;
        checkInterval = 10;
      };
      imageFile = pkgs.dockerTools.buildImage {
        name = "ultrafeeder-test";
        tag = "latest";
        copyToRoot = pkgs.buildEnv {
          name = "ultrafeeder-test-root";
          paths = [pkgs.busybox];
        };
        config = {
          Cmd = ["sleep" "infinity"];
        };
      };
      volumes = [
        "/tmp/globe_history:/var/globe_history"
        "/tmp/collectd:/var/lib/collectd"
      ];
      device = "/dev/null";
    };
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("docker-ultrafeeder.service")
    machine.wait_until_succeeds("docker inspect ultrafeeder --format '{{.State.Status}}' | grep running")
    # Check that gpsd config is present in the environment
    machine.succeed("docker exec ultrafeeder printenv | grep 'ULTRAFEEDER_CONFIG=gpsd,host.docker.internal,2947'")
    machine.succeed("docker exec ultrafeeder printenv | grep 'GPSD_MIN_DISTANCE=15'")
    machine.succeed("docker exec ultrafeeder printenv | grep 'GPSD_MLAT_WAIT=60'")
    machine.succeed("docker exec ultrafeeder printenv | grep 'GPSD_CHECK_INTERVAL=10'")
  '';
}
