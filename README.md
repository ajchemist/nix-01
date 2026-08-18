# nix-basecamp

A basecamp for expeditions into any machine — including temporary ones.
One command deploys my pre-arranged minimal setup, so work on a fresh or
borrowed system starts from a safe, fast, systematic base instead of zero.

Nix-native, for macOS and Linux. The flake **is** the CLI.

```sh
# 1) Nix (once per machine)
curl -fsSL https://install.determinate.systems/nix | sh -s -- install

# 2) Everything else — shows the module plan, asks, applies
nix run github:ajchemist/nix-basecamp
```

> **429 fallback**: `github:` fetches the repo via GitHub's archive API, which
> can rate-limit shared IPs (HTTP 429). If that happens, use the plain-git
> form — the result is bit-for-bit identical, only the transport differs:
>
> ```sh
> nix run 'git+https://github.com/ajchemist/nix-basecamp.git'
> ```
>
> (The heavy inputs are pinned in `flake.lock` and largely fetched over git
> already, so only the top-level repo fetch is affected either way.)

## Discoverability

Every module is a flake app, so the standard nix commands reveal everything:

```sh
nix flake show github:ajchemist/nix-basecamp          # list all modules/outputs
nix run  github:ajchemist/nix-basecamp#plan           # status table, read-only
nix run  github:ajchemist/nix-basecamp -- --dry-run   # same, via the default app
```

Apply everything, or a single module:

```sh
nix run github:ajchemist/nix-basecamp                  # plan -> confirm -> apply all
nix run github:ajchemist/nix-basecamp -- --yes         # no prompt
nix run github:ajchemist/nix-basecamp#karabiner-rule   # just the karabiner rule
nix run github:ajchemist/nix-basecamp#darwin           # just nix-darwin activation
nix run github:ajchemist/nix-basecamp#homebrew         # just homebrew
```

The plan looks like:

```
nix-basecamp · Darwin (arm64) · target user: alice

  [•] homebrew        Homebrew package manager                       install
  [•] nix-darwin      system profile                                 activate new generation
  [✓] karabiner       Karabiner-Elements (homebrew cask)             converge on switch
  [✓] karabiner-rule  Korean-mode left modifiers -> karabiner.json   converge on switch

Proceed? [y/N]
```

## What is managed

- **macOS** (aarch64): nix-darwin + home-manager, Homebrew casks
  (Karabiner-Elements), and Karabiner complex-modification rules upserted into
  the selected profile of `~/.config/karabiner/karabiner.json`
  (idempotent jq merge — safe against an existing, hand-edited config).
- **Linux** (x86_64): standalone home-manager.

## Target user is a runtime parameter

The repo contains no personal usernames. The apps detect the invoking user
(`id -un`) at runtime and evaluate `lib.mkDarwin { user = ...; }` /
`lib.mkHome { user = ...; }` impurely, so the same command works for any
account on any machine. The pure `darwinConfigurations.fixture` /
`homeConfigurations.fixture` outputs exist only for CI and `nix flake check`.

Activation registers the built system closure directly
(`nix-env --profile /nix/var/nix/profiles/system --set` + `activate`), so
there is no PATH/sudo juggling.

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
- Per-host module variation is supported via `lib.mkDarwin { modules = [...]; }`
  but not yet wired to any host detection.
