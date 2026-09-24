{
  self,
  lib,
  wrapperModules,
  ...
}: let
  mkColorsQml = import ./_colors.nix;

  colorsQml = pkgs: pkgs.writeText "Colors.qml" (mkColorsQml (self.lib.theme // self.lib.material));

  quickshell = pkgs:
    pkgs.quickshell.overrideAttrs (previous: {
      patches = (previous.patches or []) ++ [./quickshell-atomic-reload.patch];
    });

  iconLines = lib.splitString "\n" (builtins.readFile ./Commons/Icons.qml);

  matching = pattern:
    map builtins.head
    (builtins.filter (found: found != null)
      (map (line: builtins.match pattern line) iconLines));
in {
  lib.vjshellColors = colorsQml;

  lib.iconNames = lib.unique (
    matching ''.*property string [a-zA-Z0-9]+: "([a-z0-9_]+)".*''
    ++ matching ''.*icon: "([a-z0-9_]+)".*''
  );

  wrappers.vjshell = {
    wlib,
    pkgs,
    config,
    ...
  }: let
    src = builtins.path {
      path = ./.;
      name = "vjshell-src";
      filter = path: _type: let
        base = baseNameOf path;
      in
        !(lib.hasSuffix ".nix" base) && !(lib.hasSuffix ".patch" base) && base != "_romanize.py" && base != ".qmlls.ini" && base != "tests";
    };

    romanizePython = pkgs.python3.withPackages (p: [p.fugashi p.unidic-lite p.jaconv p.pypinyin]);

    romanize = pkgs.writeShellScriptBin "vjshell-romanize" ''
      exec ${romanizePython}/bin/python3 ${./_romanize.py} "$@"
    '';

    menuJson =
      pkgs.writeText "vjshell-menu.json"
      (builtins.toJSON (self.lib.keymap.menuEntries {inherit pkgs;}));

    qmlDir = pkgs.runCommand "vjshell-qml" {} ''
      cp -r ${src} $out
      chmod -R u+w $out
      cp ${colorsQml pkgs} $out/Commons/Colors.qml
    '';
  in {
    imports = [wlib.modules.default wrapperModules._dynamic];

    package = quickshell pkgs;
    binName = "vjshell";

    filesToExclude = ["bin/qs" "bin/quickshell"];

    flags."-p" = lib.mkIf (!config.dynamicMode) "${qmlDir}";

    runShell =
      lib.optional config.dynamicMode ''
        vjshellConfig="$NIXCONF_ROOT/modules/features/vjshell"
        if ! test -f "$vjshellConfig/shell.qml" || ! test -f "$vjshellConfig/Commons/Colors.qml"; then
          vjshellConfig=${qmlDir}
        fi
        set -- -p "$vjshellConfig" "$@"
      ''
      ++ [
        ''
          callDir="''${XDG_RUNTIME_DIR:-/tmp}/vjshell"
          mkdir -p "$callDir"
          : >> "$callDir/discord-call.json"
        ''
      ];

    runtimePkgs = [
      pkgs.mangowc

      pkgs.vj.vjproj
      pkgs.vj.vjvr
      pkgs.vj.vjmusic

      pkgs.bluez
      pkgs.networkmanager

      pkgs.bash
      pkgs.coreutils
      pkgs.gawk
      pkgs.procps
      pkgs.vj.btop

      pkgs.pwvucontrol

      pkgs.libqalculate
      pkgs.translate-shell

      romanize
      pkgs.python3Packages.syncedlyrics

      pkgs.wf-recorder

      pkgs.wl-clipboard
    ];

    env.VJSHELL_TERMINAL = self.lib.dynamicExe config.dynamicMode pkgs.vj.terminal;
    env.VJSHELL_MENU = "${menuJson}";
  };

  wrappers.vjshellDynamic = {
    imports = [wrapperModules.vjshell];
    dynamicMode = true;
  };

  checks = pkgs: {
    vjshell-colors = self.lib.mkGeneratedFileCheck {
      inherit pkgs;
      name = "vjshell-colors";
      generated = mkColorsQml (self.lib.theme // self.lib.material);
      committed = ./Commons/Colors.qml;
      path = "modules/features/vjshell/Commons/Colors.qml";
    };
    vjshell-behavior =
      pkgs.runCommand "vjshell-behavior-check" {
        nativeBuildInputs = [(quickshell pkgs) pkgs.libqalculate pkgs.dbus];
      } ''
        export QT_QPA_PLATFORM=offscreen
        ${self.lib.sandboxHome "$TMPDIR"}
        mkdir -p "$TMPDIR/bin"
        cp -r ${./.} tree
        chmod -R u+w tree
        cp ${colorsQml pkgs} tree/Commons/Colors.qml
        cat > "$TMPDIR/bin/trans" <<'SCRIPT'
        #!${pkgs.bash}/bin/bash
        if [ "''${!#}" = old ]; then sleep 0.2; fi
        printf '%s' "''${!#}"
        SCRIPT
        chmod +x "$TMPDIR/bin/trans"
        export PATH="$TMPDIR/bin:$PATH"
        echo '{}' > "$TMPDIR/vr-fixture.json"
        export VJVR_UI_FIXTURE="$TMPDIR/vr-fixture.json"
        for test in requests services controls vr devices material music; do
          cp "tree/tests/$test.qml" tree/shell.qml
          dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- timeout 15 qs -p tree > "$test.log" 2>&1 || {
            cat "$test.log"
            exit 1
          }
          cat "$test.log"
          grep -q 'PASS ' "$test.log"
          if grep -E 'Error:|ReferenceError|TypeError|Binding loop|FATAL|crashed' "$test.log"; then exit 1; fi
        done
        touch $out
      '';
    vjshell-qml =
      pkgs.runCommand "vjshell-qml-check" {
        nativeBuildInputs = [pkgs.qt6.qtdeclarative];
      } ''
        tree=${./.}
        work=$(mktemp -d)
        status=0

        cd "$tree"
        for file in $(find . -name '*.qml' | sort); do
          if ! qmlformat "$tree/$file" > "$work/formatted" 2> "$work/error"; then
            echo "cannot parse $file:"
            sed 's/^/    /' "$work/error"
            status=1
            continue
          fi
          if ! diff -u "$tree/$file" "$work/formatted" > "$work/diff"; then
            echo "not qmlformat-clean: $file"
            sed -n '3,20p' "$work/diff" | sed 's/^/    /'
            status=1
          fi
        done

        if [ "$status" -ne 0 ]; then
          echo
          echo "Fix with: qmlformat -i <file>"
          exit 1
        fi
        touch $out
      '';
  };

  packages = pkgs: {
    vjshellCommonsQml = pkgs.runCommand "vjshell-commons-qml" {} ''
      mkdir -p $out
      cp -r ${./Commons} $out/Commons
      cp -r ${./Widgets} $out/Widgets
      chmod -R u+w $out
      cp ${colorsQml pkgs} $out/Commons/Colors.qml
    '';
  };
}
