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
    casks = [
      "karabiner-elements"
    ];
  };

  programs.zsh.enable = true;

  system.stateVersion = 6;
}
