{ config, pkgs, lib, ... }:

{
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  home.activation.karabinerKoreanRule = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (import ../lib/karabiner-upsert.nix {
      inherit pkgs lib;
      ruleFile = ./karabiner/korean-left-modifiers.json;
    });
}
