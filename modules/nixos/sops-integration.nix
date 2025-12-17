{
  config,
  lib,
  ...
}: let
  mkEnvTemplate = {
    name,
    sopsFile,
    envToSecret,
  }: let
    secretNames = lib.unique (builtins.attrValues envToSecret);
    lines = lib.mapAttrsToList (envVar: secretName: "${envVar}=${config.sops.placeholder.${secretName}}") envToSecret;
  in {
    secrets = builtins.listToAttrs (
      map (secretName: {
        name = secretName;
        value = {inherit sopsFile;};
      })
      secretNames
    );
    templates = {
      ${name} = {
        content = lib.concatStringsSep "\n" (lines ++ [""]);
        mode = "0400";
      };
    };
  };

  ufCfg = config.services.ultrafeeder.sops;
  ssCfg = config.services.skystats.sops;
  piawareCfg = config.services.adsbFeeders.piaware.sops;
  fr24Cfg = config.services.adsbFeeders.flightradar24.sops;
  pfCfg = config.services.adsbFeeders.planefinder.sops;
  anCfg = config.services.adsbFeeders.airnavradar.sops;
in {
  options = {
    ultra.sops = {
      ageKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/var/lib/sops-nix/key.txt";
        description = "Path to the age private key file used by sops-nix.";
      };

      defaultSopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/etc/nixos/secrets.yaml";
        description = "Default sops file used by sops-nix when `sopsFile` is not specified per secret.";
      };
    };

    services = {
      ultrafeeder.sops = {
        enable = lib.mkEnableOption "Inject Ultrafeeder secrets using sops-nix templates (age-backed)";

        sopsFile = lib.mkOption {
          type = lib.types.str;
          example = "/etc/nixos/secrets.yaml";
          description = "SOPS file that contains the secrets referenced by `envToSecret`.";
        };

        envToSecret = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          example = {
            # Example env vars that *might* be sensitive in your deployment.
            # Put the secret values in your SOPS file under these keys.
            FEEDER_KEY = "ultrafeeder_feeder_key";
            MLAT_USER = "ultrafeeder_mlat_user";
            MLAT_PASSWORD = "ultrafeeder_mlat_password";
          };
          description = "Mapping of container environment variable name -> sops secret key name.";
        };
      };

      skystats.sops = {
        enable = lib.mkEnableOption "Inject Skystats/Postgres secrets using sops-nix templates (age-backed)";

        sopsFile = lib.mkOption {
          type = lib.types.str;
          example = "/etc/nixos/secrets.yaml";
          description = "SOPS file that contains the secrets referenced by `envToSecretApp` / `envToSecretDb`.";
        };

        envToSecretApp = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {
            DB_PASSWORD = "skystats_db_password";
          };
          description = "Mapping of Skystats container env var name -> sops secret key name.";
        };

        envToSecretDb = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {
            POSTGRES_PASSWORD = "skystats_db_password";
          };
          description = "Mapping of Postgres container env var name -> sops secret key name.";
        };
      };

      adsbFeeders = {
        piaware.sops = {
          enable = lib.mkEnableOption "Inject PiAware secrets using sops-nix templates (age-backed)";

          sopsFile = lib.mkOption {
            type = lib.types.str;
            example = "/etc/nixos/secrets.yaml";
            description = "SOPS file that contains the secrets referenced by `envToSecret`.";
          };

          envToSecret = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {
              FEEDER_ID = "piaware_FEEDER_ID";
            };
            description = "Mapping of PiAware container env var name -> sops secret key name.";
          };
        };

        flightradar24.sops = {
          enable = lib.mkEnableOption "Inject FlightRadar24 secrets using sops-nix templates (age-backed)";

          sopsFile = lib.mkOption {
            type = lib.types.str;
            example = "/etc/nixos/secrets.yaml";
            description = "SOPS file that contains the secrets referenced by `envToSecret`.";
          };

          envToSecret = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {
              FR24KEY = "flightradar24_FR24KEY";
              FR24KEY_UAT = "flightradar24_FR24KEY_UAT";
            };
            description = "Mapping of FlightRadar24 container env var name -> sops secret key name.";
          };
        };

        planefinder.sops = {
          enable = lib.mkEnableOption "Inject PlaneFinder secrets using sops-nix templates (age-backed)";

          sopsFile = lib.mkOption {
            type = lib.types.str;
            example = "/etc/nixos/secrets.yaml";
            description = "SOPS file that contains the secrets referenced by `envToSecret`.";
          };

          envToSecret = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {
              SHARECODE = "planefinder_SHARECODE";
            };
            description = "Mapping of PlaneFinder container env var name -> sops secret key name.";
          };
        };

        airnavradar.sops = {
          enable = lib.mkEnableOption "Inject AirNav Radar secrets using sops-nix templates (age-backed)";

          sopsFile = lib.mkOption {
            type = lib.types.str;
            example = "/etc/nixos/secrets.yaml";
            description = "SOPS file that contains the secrets referenced by `envToSecret`.";
          };

          envToSecret = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {
              SHARING_KEY = "airnavradar_SHARING_KEY";
            };
            description = "Mapping of AirNav Radar container env var name -> sops secret key name.";
          };
        };
      };
    };
  };

  config = let
    uf = mkEnvTemplate {
      name = "ultrafeeder-env";
      inherit (ufCfg) sopsFile envToSecret;
    };
    ssApp = mkEnvTemplate {
      name = "skystats-env";
      envToSecret = ssCfg.envToSecretApp;
      inherit (ssCfg) sopsFile;
    };
    ssDb = mkEnvTemplate {
      name = "skystats-db-env";
      envToSecret = ssCfg.envToSecretDb;
      inherit (ssCfg) sopsFile;
    };

    piaware = mkEnvTemplate {
      name = "piaware-env";
      inherit (piawareCfg) sopsFile envToSecret;
    };
    fr24 = mkEnvTemplate {
      name = "flightradar24-env";
      inherit (fr24Cfg) sopsFile envToSecret;
    };
    planefinder = mkEnvTemplate {
      name = "planefinder-env";
      inherit (pfCfg) sopsFile envToSecret;
    };
    airnavradar = mkEnvTemplate {
      name = "airnavradar-env";
      inherit (anCfg) sopsFile envToSecret;
    };
  in
    lib.mkMerge [
      # Convenience defaults for sops-nix (optional)
      {
        sops.age.keyFile = lib.mkIf (config.ultra.sops.ageKeyFile != null) (lib.mkDefault config.ultra.sops.ageKeyFile);
        sops.defaultSopsFile =
          lib.mkIf (config.ultra.sops.defaultSopsFile != null) (lib.mkDefault config.ultra.sops.defaultSopsFile);
      }

      (lib.mkIf ufCfg.enable {
        sops.secrets = uf.secrets;
        sops.templates = uf.templates;
        services.ultrafeeder.environmentFiles = [config.sops.templates."ultrafeeder-env".path];
      })

      (lib.mkIf ssCfg.enable {
        sops.secrets = ssApp.secrets // ssDb.secrets;
        sops.templates = ssApp.templates // ssDb.templates;
        services.skystats.environmentFiles = [config.sops.templates."skystats-env".path];
        services.skystats.dbEnvironmentFiles = [config.sops.templates."skystats-db-env".path];
      })

      (lib.mkIf piawareCfg.enable {
        sops.secrets = piaware.secrets;
        sops.templates = piaware.templates;
        services.adsbFeeders.piaware.environmentFiles = [config.sops.templates."piaware-env".path];
      })

      (lib.mkIf fr24Cfg.enable {
        sops.secrets = fr24.secrets;
        sops.templates = fr24.templates;
        services.adsbFeeders.flightradar24.environmentFiles = [config.sops.templates."flightradar24-env".path];
      })

      (lib.mkIf pfCfg.enable {
        sops.secrets = planefinder.secrets;
        sops.templates = planefinder.templates;
        services.adsbFeeders.planefinder.environmentFiles = [config.sops.templates."planefinder-env".path];
      })

      (lib.mkIf anCfg.enable {
        sops.secrets = airnavradar.secrets;
        sops.templates = airnavradar.templates;
        services.adsbFeeders.airnavradar.environmentFiles = [config.sops.templates."airnavradar-env".path];
      })
    ];
}
