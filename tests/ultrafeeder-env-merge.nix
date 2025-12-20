{
  pkgs,
  ultrafeederModulePath,
}:
pkgs.testers.nixosTest {
  name = "ultrafeeder-env-merge";
  nodes.machine = {...}: {
    imports = [ultrafeederModulePath];
    services.ultrafeeder = {
      enable = true;
      environment = {
        TZ = "UTC";
        CUSTOM_ENV = "present";
        ULTRAFEEDER_CONFIG = "base";
      };
      ultrafeederConfigFragments = ["extra"];
      mlatHubInputs = [
        {
          host = "piaware";
          port = 30105;
          protocol = "beast_in";
        }
      ];
    };
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("oci-containers-ultrafeeder.service")
    machine.succeed("systemctl show oci-containers-ultrafeeder.service -p Environment | grep 'CUSTOM_ENV=present'")
    machine.succeed("systemctl show oci-containers-ultrafeeder.service -p Environment | grep 'ULTRAFEEDER_CONFIG=base;extra;mlathub,piaware,30105,beast_in'")
  '';
}
