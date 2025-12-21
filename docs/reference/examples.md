# Examples & Recipes

## Example: single-host deployment

```nix
{
  imports = [
    nix-ultrafeeder.nixosModules.defaults
    nix-ultrafeeder.nixosModules.ultra
    nix-ultrafeeder.nixosModules.containerAutoUpdate
  ];

  services.ultrafeeder = {
    enable = true;
    environment = { TZ = "UTC"; READSB_DEVICE_TYPE = "rtlsdr"; };
    device = "/dev/bus/usb";
    volumes = [
      "/opt/adsb/globe_history:/var/globe_history"
      "/opt/adsb/timelapse:/var/timelapse1090"
    ];
    prometheus.enable = true;
  };

  services.skystats = {
    enable = true;
    readsbAircraftJsonUrl = "http://ultrafeeder:8080/data/aircraft.json";
    database.password = "changeme"; # use sops-nix
  };

  services.containerAutoUpdate.enable = true;
}
```

## Example: feeders + airband smoke

```nix
{
  imports = [
    nix-ultrafeeder.nixosModules.defaults
    nix-ultrafeeder.nixosModules.ultra
    nix-ultrafeeder.nixosModules.airband
    nix-ultrafeeder.nixosModules.feeders.piaware
    nix-ultrafeeder.nixosModules.feeders.flightradar24
    nix-ultrafeeder.nixosModules.feeders.planefinder
    nix-ultrafeeder.nixosModules.feeders.airnavradar
    nix-ultrafeeder.nixosModules.feeders.adsbhub
    nix-ultrafeeder.nixosModules.feeders.opensky
    nix-ultrafeeder.nixosModules.feeders.radarvirtuel
    nix-ultrafeeder.nixosModules.feeders.radar1090uk
  ];

  services.airband.enable = true;

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
}
```

## Example: offline / tarball images

```nix
let mkImage = name: /var/lib/oci-cache/${name}.tar.gz;
in {
  services.ultrafeeder.imageFile = mkImage "ultrafeeder";
  services.skystats.imageFile = mkImage "skystats";
  services.skystats.dbImageFile = mkImage "postgres";
  services.adsbFeeders.piaware.imageFile = mkImage "docker-piaware";
}
```

## Example: dual SDR devices

```nix
services.ultrafeeder.device = "/dev/bus/usb";
services.ultrafeeder.extraOptions = [
  "--device=/dev/bus/usb/001/002"
  "--device=/dev/bus/usb/001/003"
];
```

## More

- `examples/nixos-configuration.nix` — annotated host config.
- `examples/flake-auto-update.nix` — flake with the auto-update helper.

