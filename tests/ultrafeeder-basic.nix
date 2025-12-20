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
      environment = {
        TZ = "UTC";
        READSB_DEVICE_TYPE = "rtlsdr";
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
    machine.wait_for_unit("oci-containers-ultrafeeder.service")
    machine.succeed("systemctl status oci-containers-ultrafeeder.service")
  '';
}
