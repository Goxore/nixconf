{pkgs}: let
  fonttools = pkgs.python3.withPackages (python: [python.fonttools python.brotli]);

  family = "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono";

  ranges = builtins.concatStringsSep "," [
    "U+0000-00FF"
    "U+0100-017F"
    "U+0192,U+0218-021B"
    "U+0370-03FF"
    "U+0400-04FF"
    "U+2000-206F"
    "U+2070-209F"
    "U+20A0-20BF"
    "U+2100-214F"
    "U+2190-21FF"
    "U+2200-22FF"
    "U+2300-23FF"
    "U+2500-257F"
    "U+2580-259F"
    "U+25A0-25FF"
    "U+2600-27BF"
    "U+2B00-2BFF"
    "U+E000-E00A"
    "U+E0A0-E0A3"
    "U+E0B0-E0D4"
    "U+E200-E2A9"
    "U+E5FA-E6B7"
    "U+E700-E8EF"
    "U+EA60-EC1E"
    "U+ED00-EFCE"
    "U+F000-F2FF"
    "U+F300-F381"
    "U+F400-F533"
  ];

  text = builtins.concatStringsSep "," [
    "U+0000-00FF"
    "U+0100-017F"
    "U+0400-04FF"
    "U+2000-206F"
    "U+20A0-20BF"
    "U+2190-21FF"
  ];

  cut = weight: unicodes: ''
    ${fonttools}/bin/python3 -m fontTools.subset \
      ${builtins.toJSON family}/JetBrainsMonoNerdFontMono-${weight}.ttf \
      --unicodes="${unicodes}" \
      --layout-features=  \
      --flavor=woff2 \
      --output-file=$out/${pkgs.lib.toLower weight}.woff2
  '';
in
  pkgs.runCommand "vjproj-fonts" {} ''
    mkdir -p $out
    ${cut "Regular" ranges}
    ${cut "Medium" text}

    for face in $out/*.woff2; do
      echo "$(basename "$face") $(stat -c %s "$face") bytes"
    done
  ''
