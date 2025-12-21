{
  pkgs,
  skystatsModulePath,
}:
pkgs.testers.nixosTest {
  name = "skystats";
  nodes.machine = {...}: {
    imports = [skystatsModulePath];
    services.skystats = {
      enable = true;
      image = "skystats-test";
      tag = "latest";
      imageFile = pkgs.dockerTools.buildImage {
        name = "skystats-test";
        tag = "latest";
        copyToRoot = pkgs.buildEnv {
          name = "skystats-root";
          paths = [pkgs.busybox pkgs.coreutils];
        };
        config = {Cmd = ["sleep" "infinity"];};
      };
      dbImage = "postgres";
      dbTag = "17";
      dbImageFile = pkgs.dockerTools.buildImage {
        name = "postgres";
        tag = "17";
        copyToRoot = pkgs.buildEnv {
          name = "pg-root";
          paths = [pkgs.busybox pkgs.coreutils];
        };
        config = {Cmd = ["sleep" "infinity"];};
      };
      database.password = "test";
      environment = {
        PGHOST = "skystats-db";
        PGPASSWORD = "test";
      };
      database.dataDir = "/var/tmp/skystats-db";
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("docker-skystats-db.service")
    machine.wait_for_unit("docker-skystats.service")

    machine.wait_until_succeeds("docker inspect skystats-db --format '{{.State.Status}}' | grep running")
    machine.wait_until_succeeds("docker inspect skystats --format '{{.State.Status}}' | grep running")

    machine.succeed("docker inspect skystats-db --format '{{json .HostConfig.Binds}}' | grep '/var/tmp/skystats-db:/var/lib/postgresql/data'")
    machine.succeed("docker inspect skystats --format '{{json .Config.Env}}' | grep PGPASSWORD=test")
  '';
}
