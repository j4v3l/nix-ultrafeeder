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
      backend = "docker";
      image = "ultrafeeder-test";
      tag = "latest";
      environment = {
        TZ = "UTC";
        CUSTOM_ENV = "present";
        ULTRAFEEDER_CONFIG = "base";
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
    machine.wait_for_unit("docker-ultrafeeder.service")
    machine.wait_until_succeeds("docker inspect ultrafeeder --format '{{.State.Status}}' | grep running")
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep 'CUSTOM_ENV=present'")
    machine.succeed("docker inspect ultrafeeder --format '{{json .Config.Env}}' | grep 'ULTRAFEEDER_CONFIG=base;extra;mlathub,piaware,30105,beast_in'")
  '';
}
