{
  description = "NixOS flake to run sdr-enthusiasts/docker-adsb-ultrafeeder via oci-containers";

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

        checks = {
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
        };

        packages.default = pkgs.writeText "nix-ultrafeeder.txt" ''
          This flake provides NixOS modules:

            nixosModules.ultrafeeder
            nixosModules.skystats
            nixosModules.piaware
            nixosModules.flightradar24
            nixosModules.planefinder
            nixosModules.airnavradar
            nixosModules.ultra (includes sops-nix + secret injection helpers)

          See README.md for usage.
        '';
      }
    );
}
