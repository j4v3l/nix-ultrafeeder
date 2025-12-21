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
  '';
}
