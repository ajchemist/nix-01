# nix-01

One-command system bootstrap for a fresh macOS or Linux machine.

```sh
curl -fsSL https://raw.githubusercontent.com/ajchemist/nix-01/main/bootstrap.sh | bash
```

The bootstrap first prints the **module plan** — what is already installed, what is missing, and exactly what will be done — and asks for confirmation before touching anything:

```
nix-01 bootstrap · Darwin (arm64) · flake: github:ajchemist/nix-01

  [•] nix             Nix package manager                            install (Determinate Systems)
  [✓] homebrew        Homebrew package manager                       up to date
  [•] nix-darwin      system config (darwinConfigurations.default)   darwin-rebuild switch
  [✓] karabiner       Karabiner-Elements (homebrew cask)             converge on switch
  [✓] karabiner-rule  Korean-mode left modifiers -> karabiner.json   converge on switch

Proceed? [y/N]
```

Flags: `--dry-run` (plan only), `--yes` (no prompt), `--flake REF` (override source). From a local checkout, plain `./bootstrap.sh` auto-detects and uses the sibling `flake.nix`.

## What it does

1. Installs **Nix** via the [Determinate Systems installer](https://github.com/DeterminateSystems/nix-installer) if not already present (flakes enabled out of the box).
2. **macOS**: installs Homebrew if missing, then activates the **nix-darwin** configuration (`darwinConfigurations.default`), which includes:
   - `home-manager` as a nix-darwin module
   - Homebrew casks (Karabiner-Elements)
   - Karabiner complex-modification rules deployed into `~/.config/karabiner/karabiner.json` (idempotent jq upsert into the selected profile — safe to run against an existing config)
3. **Linux**: activates a standalone **home-manager** configuration.

Re-running the command is safe; every step is idempotent.

## Layout

```
bootstrap.sh                          # curl-able entry point
flake.nix                             # inputs: nixpkgs, nix-darwin, home-manager
darwin/default.nix                    # nix-darwin system config (homebrew casks, ...)
home/darwin.nix                       # home-manager (karabiner rule activation)
home/linux.nix                        # home-manager (linux)
home/karabiner/korean-left-modifiers.json   # Karabiner rule: left modifiers work in Korean mode
```

## Local iteration

```sh
./bootstrap.sh                                 # auto-detects the local flake
sudo darwin-rebuild switch --flake .#default   # after first bootstrap
```

## Notes

- `nix.enable = false` in nix-darwin: the Determinate installer owns the nix daemon and `/etc/nix/nix.conf`.
- Username is currently hardcoded (`fixture`) in `flake.nix`; parametrizing per-host/per-user is the next step.
