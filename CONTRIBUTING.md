# Contributing

Thanks for helping improve this project.

## Development prerequisites

- Nix with flakes enabled

## Quick checks

Run:

```bash
nix flake check
```

This runs:

- **Alejandra** formatting check
- **statix** lint
- **deadnix** unused code check

## Style

- Format Nix with `alejandra`
- Keep secrets out of the Nix store; prefer `environmentFiles` + `sops-nix` templates

## Submitting changes

- Keep PRs focused and small when possible
- Update README/examples when changing module options
- Include a short test note in the PR description (e.g. “`nix flake check` passed”)
