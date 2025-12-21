{
  description = "NixOS flake to run sdr-enthusiasts/docker-adsb-ultrafeeder via oci-containers (v0.1.0)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    sops-nix,
    ...
  }: let
    version = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./VERSION);
    ultrafeederModule = import ./modules/nixos/ultrafeeder.nix;
    skystatsModule = import ./modules/nixos/skystats.nix;
    piawareModule = import ./modules/nixos/feeders/piaware.nix;
    flightradar24Module = import ./modules/nixos/feeders/flightradar24.nix;
    planefinderModule = import ./modules/nixos/feeders/planefinder.nix;
    airnavradarModule = import ./modules/nixos/feeders/airnavradar.nix;
    sopsIntegrationModule = import ./modules/nixos/sops-integration.nix;
    ultraModule = {
      imports = [
        sops-nix.nixosModules.sops
        ultrafeederModule
        skystatsModule
        piawareModule
        flightradar24Module
        planefinderModule
        airnavradarModule
        sopsIntegrationModule
      ];
    };
  in
    {
      inherit version;
      nixosModules = {
        ultrafeeder = ultrafeederModule;
        skystats = skystatsModule;
        piaware = piawareModule;
        flightradar24 = flightradar24Module;
        planefinder = planefinderModule;
        airnavradar = airnavradarModule;
        inherit (sops-nix.nixosModules) sops;
        ultra = ultraModule;
        default = ultrafeederModule;
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
      in {
        formatter = pkgs.alejandra;

        # Development shell with useful tools
        devShells.default = pkgs.mkShell {
          name = "nix-ultrafeeder-dev";
          packages = with pkgs; [
            alejandra
            statix
            deadnix
            nil # Nix LSP
            sops
            age
          ];
          shellHook = ''
            lint() {
              echo "Running statix..."
              statix check . && \
              echo "Running deadnix..." && \
              deadnix --fail .
            }
            fmt() {
              alejandra .
            }
            clear
            echo
            echo "=== nix-ultrafeeder Dev Shell ==="
            echo
            echo "Available commands:"
            echo "  fmt               Format all Nix files with alejandra"
            echo "  lint              Run statix and deadnix checks"
            echo "  nix flake check   Run full CI checks (includes NixOS module tests)"
            echo "  nix build .#checks.x86_64-linux.ultrafeeder-basic   # Run a specific test (replace system as needed)"
            echo
          '';
        };

        checks = let
          isLinux = builtins.elem system ["x86_64-linux" "aarch64-linux"];
        in
          {
            alejandra =
              pkgs.runCommand "check-alejandra"
              {
                nativeBuildInputs = [pkgs.alejandra];
              }
              ''
                cd ${self}
                alejandra -c .
                touch $out
              '';

            statix =
              pkgs.runCommand "check-statix"
              {
                nativeBuildInputs = [pkgs.statix];
              }
              ''
                cd ${self}
                statix check .
                touch $out
              '';

            deadnix =
              pkgs.runCommand "check-deadnix"
              {
                nativeBuildInputs = [pkgs.deadnix];
              }
              ''
                cd ${self}
                deadnix --fail .
                touch $out
              '';
          }
          // (
            if isLinux
            then {
              ultrafeeder-basic = import ./tests/ultrafeeder-basic.nix {
                inherit pkgs;
                ultrafeederModulePath = ./modules/nixos/ultrafeeder.nix;
              };
              ultrafeeder-env-merge = import ./tests/ultrafeeder-env-merge.nix {
                inherit pkgs;
                ultrafeederModulePath = ./modules/nixos/ultrafeeder.nix;
              };
            }
            else {}
          );

        packages.default = pkgs.writeText "nix-ultrafeeder.txt" ''
          This flake provides NixOS modules:

            nixosModules.ultrafeeder
            nixosModules.skystats
            nixosModules.piaware
            nixosModules.flightradar24
            nixosModules.planefinder
            nixosModules.airnavradar
            nixosModules.ultra (includes sops-nix + secret injection helpers)

          Version: ${version}

          See README.md for usage.
        '';
      }
    );
}
