{ config, pkgs, lib, ... }:

let
  ruleFile = ./karabiner/korean-left-modifiers.json;
  ruleDesc = (builtins.fromJSON (builtins.readFile ruleFile)).description;
in
{
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  # Karabiner-Elements rewrites karabiner.json itself, so the file cannot be a
  # read-only store symlink. Instead, upsert our rule into the selected profile
  # with jq: any existing rule with the same description is replaced.
  home.activation.karabinerKoreanRule = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    karabinerDir="$HOME/.config/karabiner"
    karabinerJson="$karabinerDir/karabiner.json"
    rule=${ruleFile}
    desc=${lib.escapeShellArg ruleDesc}
    jq=${pkgs.jq}/bin/jq

    tmp=$(mktemp)
    if [ ! -f "$karabinerJson" ]; then
      "$jq" -n --slurpfile rule "$rule" \
        '{profiles: [{name: "Default profile", selected: true, complex_modifications: {rules: $rule}}]}' \
        > "$tmp"
    else
      "$jq" --slurpfile rule "$rule" --arg desc "$desc" '
        def upsert:
          .complex_modifications //= {}
          | .complex_modifications.rules =
              ((.complex_modifications.rules // []) | map(select(.description != $desc))) + $rule;
        .profiles //= []
        | (if (.profiles | length) == 0
           then .profiles = [{name: "Default profile", selected: true}]
           else . end)
        | .profiles |= (if (map(.selected == true) | any)
                        then map(if .selected == true then upsert else . end)
                        else (.[0] |= upsert)
                        end)
      ' "$karabinerJson" > "$tmp"
    fi

    if [ ! -f "$karabinerJson" ] || ! cmp -s "$tmp" "$karabinerJson"; then
      verboseEcho "Updating $karabinerJson"
      run mkdir -p "$karabinerDir"
      run install -m 0644 "$tmp" "$karabinerJson"
    fi
    rm -f "$tmp"
  '';
}
