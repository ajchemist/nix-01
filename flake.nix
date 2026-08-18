{
  description = "One-command system setup: nix run git+https://github.com/ajchemist/nix-01.git";

  inputs = {
    # Use Git rather than GitHub's archive API, which is prone to secondary
    # rate limits on shared IPs. flake.lock pins the resolved revisions.
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixpkgs-unstable&shallow=1";
    nix-darwin = {
      url = "git+https://github.com/nix-darwin/nix-darwin.git?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "git+https://github.com/nix-community/home-manager.git?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, ... }:
    let
      lib = nixpkgs.lib;

      # TODO: parametrize per-host/per-user once more machines are added
      user = "fixture";

      ruleFile = ./home/karabiner/korean-left-modifiers.json;
      ruleDesc = (builtins.fromJSON (builtins.readFile ruleFile)).description;

      mkApp = desc: drv: {
        type = "app";
        program = lib.getExe drv;
        meta.description = desc;
      };
    in
    {
      # ------------------------------------------------------------------ macOS
      darwinConfigurations.default = nix-darwin.lib.darwinSystem {
        modules = [
          ./darwin/default.nix
          home-manager.darwinModules.home-manager
          {
            nixpkgs.hostPlatform = "aarch64-darwin";
            system.primaryUser = user;
            users.users.${user}.home = "/Users/${user}";
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${user} = import ./home/darwin.nix;
          }
        ];
      };

      apps.aarch64-darwin =
        let
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          toplevel = self.darwinConfigurations.default.system;

          karabiner-rule = pkgs.writeShellApplication {
            name = "karabiner-rule";
            text = import ./lib/karabiner-upsert.nix { inherit pkgs lib ruleFile; };
          };

          homebrew = pkgs.writeShellApplication {
            name = "homebrew";
            text = ''
              if command -v brew >/dev/null 2>&1; then
                echo "homebrew: already installed ($(brew --version | head -n1))"
                exit 0
              fi
              echo "homebrew: installing"
              NONINTERACTIVE=1 /bin/bash -c \
                "$(${pkgs.curl}/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            '';
          };

          darwin = pkgs.writeShellApplication {
            name = "darwin";
            text = ''
              # nix-darwin refuses to activate over these pre-existing files;
              # move them aside once (they are replaced by symlinks).
              for f in /etc/bashrc /etc/zshrc /etc/zshenv; do
                if [ -f "$f" ] && [ ! -L "$f" ]; then
                  echo "darwin: moving $f -> $f.before-nix-darwin"
                  sudo mv "$f" "$f.before-nix-darwin"
                fi
              done
              echo "darwin: activating darwinConfigurations.default"
              sudo ${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --set ${toplevel}
              sudo ${toplevel}/activate
            '';
          };

          plan = pkgs.writeShellApplication {
            name = "plan";
            text = ''
              row() { printf '  [%s] %-15s %-46s %s\n' "$@"; }
              echo ""
              echo "nix-01 · $(uname -s) ($(uname -m)) · darwinConfigurations.default"
              echo ""
              if command -v brew >/dev/null 2>&1; then
                row "✓" homebrew "Homebrew package manager" "up to date"
              else
                row "•" homebrew "Homebrew package manager" "install"
              fi
              current="$(readlink /run/current-system 2>/dev/null || true)"
              if [ "$current" = "${toplevel}" ]; then
                row "✓" nix-darwin "system profile" "up to date"
              else
                row "•" nix-darwin "system profile" "activate new generation"
              fi
              if [ -d /Applications/Karabiner-Elements.app ]; then
                row "✓" karabiner "Karabiner-Elements (homebrew cask)" "converge on switch"
              else
                row "•" karabiner "Karabiner-Elements (homebrew cask)" "via nix-darwin switch"
              fi
              if grep -qF ${lib.escapeShellArg ruleDesc} "$HOME/.config/karabiner/karabiner.json" 2>/dev/null; then
                row "✓" karabiner-rule "Korean-mode left modifiers -> karabiner.json" "converge on switch"
              else
                row "•" karabiner-rule "Korean-mode left modifiers -> karabiner.json" "via nix-darwin switch"
              fi
              echo ""
            '';
          };

          bootstrap = pkgs.writeShellApplication {
            name = "bootstrap";
            text = ''
              assume_yes=0
              dry_run=0
              for a in "$@"; do
                case "$a" in
                  -y|--yes) assume_yes=1 ;;
                  -n|--dry-run) dry_run=1 ;;
                  *) echo "unknown argument: $a" >&2; exit 1 ;;
                esac
              done

              ${lib.getExe plan}
              if [ "$dry_run" = 1 ]; then
                echo "(dry run — nothing was changed)"
                exit 0
              fi

              if [ "$assume_yes" != 1 ]; then
                if [ -r /dev/tty ]; then
                  printf 'Proceed? [y/N] ' > /dev/tty
                  read -r ans < /dev/tty || ans=""
                  case "$ans" in
                    y|Y|yes|YES) ;;
                    *) exit 1 ;;
                  esac
                else
                  echo "no terminal for confirmation; pass --yes" >&2
                  exit 1
                fi
              fi

              ${lib.getExe homebrew}
              ${lib.getExe darwin}
              echo ""
              echo "result:"
              ${lib.getExe plan}
            '';
          };
        in
        {
          default = mkApp "Plan, confirm, and apply the full macOS setup" bootstrap;
          plan = mkApp "Show module status (read-only)" plan;
          homebrew = mkApp "Install Homebrew if missing" homebrew;
          darwin = mkApp "Activate darwinConfigurations.default (nix-darwin)" darwin;
          karabiner-rule = mkApp "Upsert the Korean-mode left-modifier rule into karabiner.json" karabiner-rule;
        };

      # ------------------------------------------------------------------ Linux
      homeConfigurations."${user}-linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./home/linux.nix
          {
            home.username = user;
            home.homeDirectory = "/home/${user}";
          }
        ];
      };

      apps.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          home = pkgs.writeShellApplication {
            name = "home";
            text = ''
              exec ${self.homeConfigurations."${user}-linux".activationPackage}/activate
            '';
          };
        in
        {
          default = mkApp "Activate the home-manager configuration" home;
          home = mkApp "Activate the home-manager configuration" home;
        };
    };
}
