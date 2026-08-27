{ pkgs, ... }:

{
  # The Determinate Systems installer owns the nix daemon and /etc/nix/nix.conf;
  # letting nix-darwin manage nix as well would conflict.
  nix.enable = false;

  environment.systemPackages = with pkgs; [
    git
    jq
  ];

  homebrew = {
    enable = true;
    # Declared casks/formulae are the only ones allowed to stay: anything
    # installed by hand is uninstalled on switch (no drift between machines).
    onActivation.cleanup = "uninstall";
    casks = [
      "karabiner-elements"
    ];
  };

  programs.zsh.enable = true;

  # Skip building manpages/options docs for the system: faster switches, and
  # avoids the options.json store-path-context warning with git-fetched flakes.
  documentation.enable = false;

  system.stateVersion = 6;
}
