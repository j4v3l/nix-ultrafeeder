{
  pkgs,
  feedersModulePaths,
  airbandModulePath,
}:
pkgs.testers.nixosTest {
  name = "feeders-airband";
  nodes.machine = {...}: {
    imports = feedersModulePaths ++ [airbandModulePath];

    services.adsbFeeders = {
      piaware.enable = true;
      flightradar24.enable = true;
      planefinder.enable = true;
      airnavradar.enable = true;
      adsbhub.enable = true;
      opensky.enable = true;
      radarvirtuel.enable = true;
      radar1090uk.enable = true;
    };

    services.airband = {
      enable = true;
      device = "/dev/null";
    };

    # Provide tiny in-vm images for every container to avoid network pulls.
    # Name each image to match the module's configured repository so the container
    # finds the locally loaded image instead of pulling from GHCR.
    virtualisation.oci-containers.containers = let
      mkImage = repo:
        pkgs.dockerTools.buildImage {
          name = repo;
          tag = "latest";
          copyToRoot = pkgs.buildEnv {
            name = "${repo}-root";
            paths = [pkgs.busybox];
          };
          config = {Cmd = ["sleep" "infinity"];};
        };
    in {
      piaware.imageFile = mkImage "ghcr.io/sdr-enthusiasts/docker-piaware";
      flightradar24.imageFile = mkImage "ghcr.io/sdr-enthusiasts/docker-flightradar24";
      planefinder.imageFile = mkImage "ghcr.io/sdr-enthusiasts/docker-planefinder";
      airnavradar.imageFile = mkImage "ghcr.io/sdr-enthusiasts/docker-airnavradar";
      adsbhub.imageFile = mkImage "ghcr.io/sdr-enthusiasts/docker-adsbhub";
      opensky.imageFile = mkImage "ghcr.io/sdr-enthusiasts/docker-opensky-network";
      radarvirtuel.imageFile = mkImage "ghcr.io/sdr-enthusiasts/docker-radarvirtuel";
      radar1090uk.imageFile = mkImage "ghcr.io/sdr-enthusiasts/docker-radar-uk";
      airband.imageFile = mkImage "ghcr.io/sdr-enthusiasts/docker-rtlsdrairband";
    };
  };

  testScript = ''
    machine.start()

    for svc in [
      "piaware",
      "flightradar24",
      "planefinder",
      "airnavradar",
      "adsbhub",
      "opensky",
      "radarvirtuel",
      "radar1090uk",
      "airband",
    ]:
        machine.wait_for_unit(f"docker-{svc}.service")
        machine.wait_until_succeeds(
            "docker inspect {} --format '{{{{.State.Status}}}}' | grep running".format(svc)
        )
  '';
}
