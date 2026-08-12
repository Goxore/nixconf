{self, ...}: let
  themeFile = "system24-gruvbox.theme.css";

  renameApp = pkgs: appName: displayName:
    pkgs.runCommand "${appName}-${pkgs.vesktop.version}" {
      nativeBuildInputs = [pkgs.asar pkgs.jq];
      meta = pkgs.vesktop.meta // {mainProgram = appName;};
    } ''
      cp -r ${pkgs.vesktop} $out
      chmod -R u+w $out
      resources=$out/opt/Vesktop/resources

      asar extract $resources/app.asar app
      jq '.name = "${appName}"' app/package.json > renamed.json
      mv renamed.json app/package.json
      rm -rf $resources/app.asar $resources/app.asar.unpacked
      asar pack app $resources/app.asar --unpack "*.node"

      substituteInPlace $out/bin/vesktop --replace-fail ${pkgs.vesktop} $out
      mv $out/bin/vesktop $out/bin/${appName}

      mv $out/share/applications/vesktop.desktop $out/share/applications/${appName}.desktop
      substituteInPlace $out/share/applications/${appName}.desktop \
        --replace-fail "Exec=vesktop" "Exec=${appName}" \
        --replace-fail "Name=Vesktop" "Name=${displayName}" \
        --replace-fail "StartupWMClass=Vesktop" "StartupWMClass=${appName}"
    '';

  mkVesktop = {
    appName,
    displayName,
  }: {
    config,
    wlib,
    pkgs,
    lib,
    ...
  }: let
    installTheme = ''
      dataDir="''${XDG_CONFIG_HOME:-$HOME/.config}/${appName}"
      mkdir -p "$dataDir/themes" "$dataDir/settings"
      ln -sfT ${config.constructFiles.system24.path} "$dataDir/themes/${themeFile}"
      settings="$dataDir/settings/settings.json"
      [ -f "$settings" ] || echo '{}' > "$settings"
      ${lib.getExe pkgs.jq} '.enabledThemes = ["${themeFile}"]' "$settings" > "$settings.new" \
        && mv "$settings.new" "$settings"
    '';
  in {
    imports = [wlib.modules.default];

    package =
      if appName == "vesktop"
      then pkgs.vesktop
      else renameApp pkgs appName displayName;

    binName = appName;

    runShell = [installTheme];

    constructFiles.system24 = {
      relPath = "share/${appName}/themes/${themeFile}";
      content = ''
        /**
         * @name system24 (gruvbox)
         * @description a tui-style discord theme.
         * @author refact0r
         * @version 2.0.0
         * @source https://github.com/refact0r/system24
        */

        @import url('${self.discordTheme.system24Url}');

        ${self.discordTheme.variables}

      '';
    };
  };
in {
  flake.wrappers.vesktop = mkVesktop {
    appName = "vesktop";
    displayName = "Vesktop";
  };

  flake.wrappers.vesktop-alt = mkVesktop {
    appName = "vesktop-alt";
    displayName = "Vesktop (alt)";
  };
}
