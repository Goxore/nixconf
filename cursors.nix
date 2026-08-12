{self, ...}: {
  perSystem = {pkgs, ...}: {
    packages.cursors = pkgs.stdenvNoCC.mkDerivation {
      pname = "bibata-gruvbox-cursors";
      inherit (pkgs.bibata-cursors) version src bitmaps;

      nativeBuildInputs = [
        pkgs.clickgen
        pkgs.imagemagick
      ];

      buildPhase = ''
        runHook preBuild

        cp -r $bitmaps/Bibata-Modern-Ice bitmaps
        chmod -R u+w bitmaps
        for bitmap in bitmaps/*.png; do
          magick "$bitmap" -channel RGB +level-colors 'black,${self.theme.base06}' +channel "PNG32:$bitmap"
        done

        ctgen configs/normal/x.build.toml \
          -p x11 \
          -d bitmaps \
          -n '${self.cursor.name}' \
          -c 'Bibata cursors recolored to the gruvbox foreground'

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        install -dm 0755 $out/share/icons
        cp -rf themes/* $out/share/icons/

        runHook postInstall
      '';
    };
  };
}
