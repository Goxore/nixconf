{
  self,
  lib,
  ...
}: let
  mkColorsQml = import ./_colors.nix;
in {
  flake.vjshellDynamicExe = "/run/current-system/sw/bin/vjshell";

  flake.wrappers.vjshell = {
    wlib,
    pkgs,
    ...
  }: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";

    src = builtins.path {
      path = ./.;
      name = "vjshell-src";
      filter = path: _type: let
        base = baseNameOf path;
      in
        base != "default.nix" && base != "_colors.nix" && base != ".qmlls.ini";
    };

    colorsQml = pkgs.writeText "Colors.qml" (mkColorsQml self.theme);

    qmlDir = pkgs.runCommand "vjshell-qml" {} ''
      cp -r ${src} $out
      chmod -R u+w $out
      cp ${colorsQml} $out/Commons/Colors.qml
    '';
  in {
    imports = [wlib.modules.default];

    package = pkgs.quickshell;
    binName = "vjshell";

    filesToExclude = ["bin/qs" "bin/quickshell"];

    flags."-p" = "${qmlDir}";

    runtimePkgs = [
      pkgs.mangowc

      selfpkgs.vjproj

      pkgs.bluez
      pkgs.networkmanager

      pkgs.bash
      pkgs.coreutils
      pkgs.procps
      selfpkgs.btop

      pkgs.pwvucontrol

      pkgs.libqalculate

      pkgs.wl-clipboard
    ];

    env.VJSHELL_TERMINAL = lib.getExe selfpkgs.terminal;
  };

  perSystem = {pkgs, ...}: {
    checks.vjshell-qml =
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

    checks.vjshell-colors = self.lib.mkGeneratedFileCheck {
      inherit pkgs;
      name = "vjshell-colors";
      generated = mkColorsQml self.theme;
      committed = ./Commons/Colors.qml;
      path = "wrappedPrograms/vjshell/Commons/Colors.qml";
    };

    packages.vjshellCommonsQml = pkgs.runCommand "vjshell-commons-qml" {} ''
      mkdir -p $out
      cp -r ${./Commons} $out/Commons
      cp -r ${./Widgets} $out/Widgets
      chmod -R u+w $out
      cp ${pkgs.writeText "Colors.qml" (mkColorsQml self.theme)} $out/Commons/Colors.qml
    '';
  };
}
