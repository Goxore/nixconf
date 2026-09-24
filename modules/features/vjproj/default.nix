{
  inputs,
  lib,
  self,
  ...
}: let
  mkThemeCss = import ./_theme.nix;
  mkIcons = import ./_icons.nix;
  mkAppIcon = import ./_appicon.nix;
  mkManifest = import ./_manifest.nix;
  mkFonts = import ./_fonts.nix;

  glyphs =
    map builtins.head
    (builtins.filter (found: found != null)
      (map (builtins.match "  [a-zA-Z]+: \"([a-z0-9_]+)\",")
        (lib.splitString "\n" (builtins.readFile ./page/src/lib/glyphs.js))));
in {
  lib.vjproj.port = 8422;

  lib.vjproj.machines = builtins.attrNames self.nixosConfigurations;

  packages = pkgs: let
    icons = mkIcons {
      inherit pkgs;
      names = lib.unique (self.lib.iconNames ++ glyphs);
    };

    appIcon = mkAppIcon {
      inherit icons pkgs;
      inherit (self.lib) material;
      glyph = "smart_toy";
    };

    fonts = mkFonts {inherit pkgs;};

    page = pkgs.buildNpmPackage {
      pname = "vjproj-page";
      version = "0.1.0";

      src = lib.fileset.toSource {
        root = ./page;
        fileset = lib.fileset.unions [
          ./page/package.json
          ./page/package-lock.json
          ./page/build.mjs
          ./page/src
          ./page/tests
          ./page/www
        ];
      };

      npmDepsHash = "sha256-vD3fcozXjRBZdITMrDbwYF5dViNORVwJyAzKv4A+TSE=";
      npmFlags = ["--ignore-scripts"];

      ESBUILD_BINARY_PATH = "${pkgs.esbuild}/bin/esbuild";

      dontNpmBuild = true;

      buildPhase = ''
        runHook preBuild
        node build.mjs src/main.jsx app.js
        runHook postBuild
      '';

      doCheck = true;
      checkPhase = ''
        runHook preCheck
        node build.mjs tests/fixtures/ui.jsx tests/.built/ui.mjs
        node --test "tests/*.test.mjs"
        runHook postCheck
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp www/index.html www/sw.js app.js app.css $out/
        runHook postInstall
      '';
    };

    www = pkgs.runCommand "vjproj-www" {} ''
      mkdir -p $out
      cp ${page}/index.html $out/index.html
      cp ${page}/sw.js $out/sw.js
      cp ${page}/app.js $out/app.js
      cp ${page}/app.css $out/app.css
      cp ${pkgs.writeText "theme.css" (mkThemeCss {inherit (self.lib) ansi material;})} $out/theme.css
      cp ${pkgs.writeText "manifest.webmanifest" (mkManifest self.lib.material)} $out/manifest.webmanifest
      cp ${icons}/icons.woff2 $out/icons.woff2
      cp ${icons}/icons.json $out/icons.json
      cp ${appIcon}/icon-192.png ${appIcon}/icon-512.png ${appIcon}/icon-mask.png $out/
      cp ${fonts}/regular.woff2 ${fonts}/medium.woff2 $out/
    '';

    unwrapped = self.lib.rustCrate pkgs "vjproj" {
      preCheck = ''
        export HOME=$(mktemp -d)
        export XDG_RUNTIME_DIR=$(mktemp -d)
      '';

      meta.description = "Project workspace groups for mango, reachable from your phone";
    };
  in {
    vjproj = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = unwrapped;
      binName = "vjproj";
      runtimePkgs = [pkgs.mangowc pkgs.vj.tmux pkgs.tailscale pkgs.curl];
      env.VJPROJ_WWW = "${www}";
      env.VJPROJ_MACHINES = lib.concatStringsSep "," self.lib.vjproj.machines;
    };
  };

  devShells = pkgs: {
    vjproj = self.lib.rustShell pkgs [pkgs.mangowc pkgs.vj.tmux pkgs.tailscale pkgs.curl pkgs.nodejs];
  };
}
