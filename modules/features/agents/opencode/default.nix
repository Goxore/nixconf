{
  lib,
  wrapperModules,
  ...
}: {
  wrappers.opencode = {
    wlib,
    pkgs,
    ...
  }: let
    plugin = pkgs.writeText "vjproj-opencode-plugin.js" (
      builtins.replaceStrings ["@vjproj@"] [(lib.getExe pkgs.vj.vjproj)] (builtins.readFile ./plugin.js)
    );
  in {
    imports = [wlib.modules.default wrapperModules._agent];

    package = pkgs.opencode;

    agent = {
      kind = "opencode";
      configVar = "OPENCODE_CONFIG_DIR";
    };

    runShell = [
      ''
        ${pkgs.coreutils}/bin/install -Dm644 ${plugin} "$OPENCODE_CONFIG_DIR/plugins/vjproj.js"
        if [ -f "$OPENCODE_CONFIG_DIR/AGENTS.md" ]; then
          printf '%s\n' '{"instructions":["AGENTS.md"]}' > "$OPENCODE_CONFIG_DIR/opencode.json"
          export OPENCODE_CONFIG="$OPENCODE_CONFIG_DIR/opencode.json"
        fi
      ''
    ];
  };
}
