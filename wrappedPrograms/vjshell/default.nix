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
    checks.vjshell-colors =
      pkgs.runCommand "vjshell-colors-check" {
        generated = mkColorsQml self.theme;
        passAsFile = ["generated"];
      } ''
        if ! diff -u "$generatedPath" ${./Commons/Colors.qml}; then
          echo
          echo "wrappedPrograms/vjshell/Commons/Colors.qml is out of sync with theme.nix."
          echo "Regenerate it with:"
          echo "  nix eval --raw .#checks.${pkgs.stdenv.hostPlatform.system}.vjshell-colors.generated \\"
          echo "    > wrappedPrograms/vjshell/Commons/Colors.qml"
          exit 1
        fi
        touch $out
      '';

    packages.vjshellCommonsQml = pkgs.runCommand "vjshell-commons-qml" {} ''
      mkdir -p $out
      cp -r ${./Commons} $out/Commons
      cp -r ${./Widgets} $out/Widgets
      chmod -R u+w $out
      cp ${pkgs.writeText "Colors.qml" (mkColorsQml self.theme)} $out/Commons/Colors.qml
    '';
  };
}
