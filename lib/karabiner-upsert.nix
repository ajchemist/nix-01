# Idempotent upsert of a Karabiner complex-modification rule into the selected
# profile of ~/.config/karabiner/karabiner.json. Karabiner rewrites that file
# itself, so it cannot be a store symlink; we merge with jq instead. Any
# existing rule with the same description is replaced.
#
# Shared by the standalone `#karabiner-rule` flake app and the home-manager
# activation in home/darwin.nix.
{ pkgs, lib, ruleFile }:

let
  ruleDesc = (builtins.fromJSON (builtins.readFile ruleFile)).description;
in
''
  karabinerDir="$HOME/.config/karabiner"
  karabinerJson="$karabinerDir/karabiner.json"
  jq=${pkgs.jq}/bin/jq
  rule=${ruleFile}
  desc=${lib.escapeShellArg ruleDesc}

  tmp="$(mktemp)"
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
    mkdir -p "$karabinerDir"
    install -m 0644 "$tmp" "$karabinerJson"
    echo "karabiner-rule: updated $karabinerJson"
  else
    echo "karabiner-rule: already up to date"
  fi
  rm -f "$tmp"
''
