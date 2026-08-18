# nix-01

Nix-native system setup for macOS and Linux. The flake **is** the CLI.

```sh
# 1) Nix (once per machine)
curl -fsSL https://install.determinate.systems/nix | sh -s -- install

# 2) Everything else — shows the module plan, asks, applies
nix run 'git+https://github.com/ajchemist/nix-01.git'
```

## Discoverability

Every module is a flake app, so the standard nix commands reveal everything:

```sh
nix flake show 'git+https://github.com/ajchemist/nix-01.git'        # list all modules/outputs
nix run 'git+https://github.com/ajchemist/nix-01.git#plan'         # status table, read-only
nix run 'git+https://github.com/ajchemist/nix-01.git' -- --dry-run # same, via the default app
```

Apply everything, or a single module:

```sh
nix run 'git+https://github.com/ajchemist/nix-01.git'                # plan -> confirm -> apply all
nix run 'git+https://github.com/ajchemist/nix-01.git' -- --yes       # no prompt
nix run 'git+https://github.com/ajchemist/nix-01.git#karabiner-rule' # just the karabiner rule
nix run 'git+https://github.com/ajchemist/nix-01.git#darwin'         # just nix-darwin activation
nix run 'git+https://github.com/ajchemist/nix-01.git#homebrew'       # just homebrew
```

The plan looks like:

```
nix-01 · Darwin (arm64) · darwinConfigurations.default

  [•] homebrew        Homebrew package manager                       install
  [•] nix-darwin      system profile                                 activate new generation
  [✓] karabiner       Karabiner-Elements (homebrew cask)             converge on switch
  [✓] karabiner-rule  Korean-mode left modifiers -> karabiner.json   converge on switch

Proceed? [y/N]
```

## What is managed

- **macOS** (`darwinConfigurations.default`, aarch64): nix-darwin + home-manager,
  Homebrew casks (Karabiner-Elements), and Karabiner complex-modification rules
  upserted into the selected profile of `~/.config/karabiner/karabiner.json`
  (idempotent jq merge — safe against an existing, hand-edited config).
- **Linux** (`homeConfigurations.fixture-linux`, x86_64): standalone home-manager.

Activation uses the flake-built system closure directly
(`nix-env --profile /nix/var/nix/profiles/system --set` + `activate`), so there
is no nested flake evaluation and no PATH/sudo juggling.

## Layout

```
flake.nix                       # inputs + module apps (the CLI surface)
darwin/default.nix              # nix-darwin system config (homebrew casks, ...)
home/darwin.nix                 # home-manager (karabiner rule activation)
home/linux.nix                  # home-manager (linux)
home/karabiner/*.json           # Karabiner rules
lib/karabiner-upsert.nix        # shared jq upsert (app + home-manager activation)
```

## Local iteration

```sh
nix run .#plan
nix run .            # or: nix run .#darwin
```

## Notes

- `nix.enable = false` in nix-darwin: the Determinate installer owns the nix
  daemon and `/etc/nix/nix.conf`.
- Username (`fixture`) and darwin arch (aarch64) are currently hardcoded in
  `flake.nix`; per-host/per-user parametrization is the next step.
