{self, ...}: let
  themeFile = "system24-gruvbox.theme.css";

  vesktopFor = pkgs:
    pkgs.vesktop.override {
      withSystemVencord = true;
      vencord = pkgs.vj.vencord;
    };

  renameApp = pkgs: appName: displayName: let
    vesktop = vesktopFor pkgs;
  in
    pkgs.runCommand "${appName}-${vesktop.version}" {
      nativeBuildInputs = [pkgs.asar pkgs.jq];
      meta = vesktop.meta // {mainProgram = appName;};
    } ''
      cp -r ${vesktop} $out
      chmod -R u+w $out
      resources=$out/opt/Vesktop/resources

      asar extract $resources/app.asar app
      jq '.name = "${appName}"' app/package.json > renamed.json
      mv renamed.json app/package.json
      rm -rf $resources/app.asar $resources/app.asar.unpacked
      asar pack app $resources/app.asar --unpack "*.node"

      substituteInPlace $out/bin/vesktop --replace-fail ${vesktop} $out
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
    themeCss =
      pkgs.runCommand themeFile {
        header = ''
          /**
           * @name system24 (gruvbox)
           * @description a tui-style discord theme.
           * @author refact0r
           * @version 2.0.0
           * @source https://github.com/refact0r/system24
          */
        '';
        passAsFile = ["header"];
      } ''
        cat "$headerPath" ${self.lib.discordTheme.stylesheet pkgs} > $out
      '';

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
      then vesktopFor pkgs
      else renameApp pkgs appName displayName;

    binName = appName;

    runShell = [installTheme];

    constructFiles.system24 = {
      relPath = "share/${appName}/themes/${themeFile}";
      builder = ''cp ${themeCss} "$2"'';
    };
  };
in {
  wrappers.vesktop = mkVesktop {
    appName = "vesktop";
    displayName = "Vesktop";
  };

  wrappers.vesktop-alt = mkVesktop {
    appName = "vesktop-alt";
    displayName = "Vesktop (alt)";
  };
}
