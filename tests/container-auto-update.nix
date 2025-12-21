{
  pkgs,
  containerAutoUpdateModulePath,
}:
pkgs.testers.nixosTest {
  name = "container-auto-update";
  nodes.machine = _: let
    inherit (pkgs) lib;
    dockerStub = pkgs.writeShellScriptBin "docker" ''
      state=/tmp/docker-stub-state
      cmd="$1"; shift
      case "$cmd" in
        image)
          sub="$1"; shift
          if [ "$sub" = "inspect" ]; then
            # Ignore the rest of the args (--format ... image)
            if [ -e "$state" ]; then
              echo "sha2"
            else
              echo "sha1"
            fi
          fi
          ;;
        pull)
          touch "$state"
          ;;
      esac
      exit 0
    '';
  in {
    imports = [containerAutoUpdateModulePath];

    services.containerAutoUpdate = {
      enable = true;
      backend = "docker";
      images = ["test/image:latest"];
      units = ["dummy.service"];
      onCalendar = "*-*-* *:*:00";
    };

    systemd.services.container-auto-update.path = lib.mkForce [dockerStub pkgs.coreutils pkgs.systemd];

    systemd.services.dummy = {
      description = "dummy service to observe restarts";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "dummy-run" ''
          echo run >> /tmp/dummy-run
        '';
      };
    };
  };

  testScript = ''
    machine.start()
    machine.succeed("systemctl start dummy.service")
    machine.succeed("grep run /tmp/dummy-run")

    machine.succeed("systemctl start container-auto-update.service")
    machine.succeed("grep -c run /tmp/dummy-run | grep 2")
  '';
}
