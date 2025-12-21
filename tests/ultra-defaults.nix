{
  pkgs,
  ultrafeederModulePath,
  defaultsModulePath,
  piawareModulePath,
  adsbhubModulePath,
  airnavradarModulePath,
  flightradar24ModulePath,
  openskyModulePath,
  planefinderModulePath,
  radarvirtuelModulePath,
  radar1090ukModulePath,
  airbandModulePath,
  skystatsModulePath,
}:
pkgs.testers.nixosTest {
  name = "ultra-defaults";
  nodes.machine = {...}: {
    imports = [
      defaultsModulePath
      ultrafeederModulePath
      piawareModulePath
      adsbhubModulePath
      airnavradarModulePath
      flightradar24ModulePath
      openskyModulePath
      planefinderModulePath
      radarvirtuelModulePath
      radar1090ukModulePath
      airbandModulePath
      skystatsModulePath
    ];

    ultra.defaults = {
      ultrafeeder = {
        image = "ultra-def";
        tag = "v1";
        device = "/dev/bus/usb";
        ports = ["18080:80"];
        volumes = ["/var/tmp/ultra-def:/var/lib/ultra"];
      };
      feeders = {
        backend = "docker";
        piawareImage = "piaware-def";
        feederTag = "v9";
      };
    };

    services = {
      ultrafeeder = {
        enable = true;
        imageFile = pkgs.dockerTools.buildImage {
          name = "ultra-def";
          tag = "v1";
          copyToRoot = pkgs.buildEnv {
            name = "ultra-def-root";
            paths = [pkgs.busybox];
          };
          config = {Cmd = ["sleep" "infinity"];};
        };
        environment = {TZ = "UTC";};
      };

      adsbFeeders = {
        piaware = {
          enable = true;
          imageFile = pkgs.dockerTools.buildImage {
            name = "piaware-def";
            tag = "v9";
            copyToRoot = pkgs.buildEnv {
              name = "piaware-def-root";
              paths = [pkgs.busybox];
            };
            config = {Cmd = ["sleep" "infinity"];};
          };
          environment = {TZ = "UTC";};
        };

        adsbhub.enable = true;
        airnavradar.enable = true;
        flightradar24.enable = true;
        opensky.enable = true;
        radarvirtuel.enable = true;
        radar1090uk.enable = true;
      };

      airband.enable = true;
    };
  };

  testScript = ''
    machine.start()

    machine.wait_for_unit("docker-ultrafeeder.service")
    machine.wait_for_unit("docker-piaware.service")

    machine.wait_until_succeeds("docker inspect ultrafeeder --format '{{.Config.Image}}' | grep 'ultra-def:v1'")
    machine.wait_until_succeeds("docker inspect piaware --format '{{.Config.Image}}' | grep 'piaware-def:v9'")

    machine.succeed("docker inspect ultrafeeder --format '{{json .HostConfig.PortBindings}}' | grep 18080")
    machine.succeed("docker inspect ultrafeeder --format '{{json .HostConfig.Binds}}' | grep '/var/tmp/ultra-def:/var/lib/ultra'")
  '';
}
