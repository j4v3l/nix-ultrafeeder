# Testing

The flake includes NixOS VM tests to exercise modules and options.

## Run all checks

```bash
nix flake check
```

## Run a specific test

```bash
nix build .#checks.x86_64-linux.ultrafeeder-options
```

Available checks (on Linux systems):

- `ultrafeeder-basic`, `ultrafeeder-env-merge`, `ultrafeeder-options`
- `ultra-defaults`
- `feeders-airband`
- `skystats`
- `container-auto-update`

## Tips

- Tests build tiny local OCI images with `dockerTools.buildImage` to avoid network pulls; keep it that way for reliability.
- If you change module options, update or add a test alongside the change.
- For faster iterations on one test: `nix build .#checks.x86_64-linux.<name> -L`.

