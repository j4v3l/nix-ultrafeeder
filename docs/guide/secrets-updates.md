# Secrets & Auto-Update

## Secrets with sops-nix (dummy-proof)

Skystats needs a Postgres password; Ultrafeeder and feeders often need API keys. Use `sops-nix` to inject secrets as env files kept out of the Nix store.

### Step-by-step setup

1) Install tooling (in your flake or host): `sops` and `age`.
2) Generate an age key **once per host**:
   ```
   sudo install -d -m 0700 /var/lib/sops-nix
   sudo age-keygen -o /var/lib/sops-nix/key.txt
   sudo chmod 600 /var/lib/sops-nix/key.txt
   ```
3) Note the public recipient printed by `age-keygen` (starts with `age1...`).
4) Create `/etc/nixos/secrets.yaml` with your values (example below).
5) Encrypt it:
   ```
   sops --encrypt --age <your-age-recipient> /etc/nixos/secrets.yaml > /etc/nixos/secrets.enc.yaml
   sudo mv /etc/nixos/secrets.enc.yaml /etc/nixos/secrets.yaml
   sudo chmod 600 /etc/nixos/secrets.yaml
   ```
6) Add sops-nix wiring (see next block) and rebuild.

### Configure sops-nix

```nix
{
  imports = [
    nix-ultrafeeder.nixosModules.defaults
    nix-ultrafeeder.nixosModules.ultra
  ];

  ultra.sops = {
    ageKeyFile = "/var/lib/sops-nix/key.txt";
    defaultSopsFile = "/etc/nixos/secrets.yaml";
  };
}
```

### Example secrets.yaml (matches module defaults)

```yaml
# /etc/nixos/secrets.yaml (encrypted with sops)
ultrafeeder_feeder_key: "REPLACE_ME"
ultrafeeder_mlat_user: "mlat-user"
ultrafeeder_mlat_password: "mlat-pass"
piaware_feeder_id: "00000000-0000-0000-0000-000000000000"
skystats_db_password: "change-me"
# add more feeder credentials as needed, then map via envToSecret
```

### Skystats secrets

```nix
services.skystats.sops = {
  enable = true;
  sopsFile = "/etc/nixos/secrets.yaml";
  # DB_PASSWORD/POSTGRES_PASSWORD default to "skystats_db_password" in the example template.
};
```

### Ultrafeeder secrets

```nix
services.ultrafeeder.sops = {
  enable = true;
  sopsFile = "/etc/nixos/secrets.yaml";
  envToSecret = {
    FEEDER_KEY = "ultrafeeder_feeder_key";
    MLAT_USER = "ultrafeeder_mlat_user";
    MLAT_PASSWORD = "ultrafeeder_mlat_password";
  };
};
```

### Feeder secrets

Each feeder supports `environmentFiles` and `sops` helpers. Example (PiAware):

```nix
services.adsbFeeders.piaware.sops = {
  enable = true;
  sopsFile = "/etc/nixos/secrets.yaml";
  envToSecret = { FEEDER_ID = "piaware_feeder_id"; };
};
```

## Container auto-update

The optional `services.containerAutoUpdate` module pulls images and restarts units when digests change.

```nix
services.containerAutoUpdate = {
  enable = true;
  backend = "docker"; # or "podman"
  onCalendar = "*-*-* 03:00:00"; # daily
  # images / units default from enabled modules; override if needed
  # images = [ "ghcr.io/sdr-enthusiasts/docker-adsb-ultrafeeder:latest" ];
  # units = [ "docker-ultrafeeder.service" "docker-skystats.service" ];
};
```

In tests/CI, you can stub the backend by placing a custom binary earlier in `systemd.services.container-auto-update.path`.

