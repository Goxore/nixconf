{
  pkgs,
  names,
}: let
  fonttools = pkgs.python3.withPackages (python: [python.fonttools python.brotli]);

  wanted = pkgs.writeText "vjproj-icon-names" (builtins.concatStringsSep "\n" names);

  face = "${pkgs.material-symbols}/share/fonts/truetype/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf";

  resolve = pkgs.writeText "vjproj-resolve-icons.py" ''
    import json, sys
    from fontTools.ttLib import TTFont

    font = TTFont(sys.argv[1])
    names = sys.argv[2]
    wanted = [n for n in open(names).read().split() if n]

    cmap = font.getBestCmap()
    glyph_of_char = {}
    codepoint_of_glyph = {}
    for point, glyph in cmap.items():
        glyph_of_char.setdefault(chr(point), glyph)
        codepoint_of_glyph.setdefault(glyph, point)

    joined = {}
    def collect(table):
        if table.__class__.__name__ == "ExtensionSubst":
            return collect(table.ExtSubTable)
        if table.__class__.__name__ != "LigatureSubst":
            return
        for first, ligatures in table.ligatures.items():
            for ligature in ligatures:
                joined[tuple([first] + list(ligature.Component))] = ligature.LigGlyph

    for lookup in font["GSUB"].table.LookupList.Lookup:
        for table in lookup.SubTable:
            collect(table)

    found, missing = {}, []
    for name in wanted:
        sequence = tuple(glyph_of_char.get(ch) for ch in name)
        glyph = joined.get(sequence) if all(sequence) else None
        point = codepoint_of_glyph.get(glyph) if glyph else None
        if point is None:
            missing.append(name)
        else:
            found[name] = point

    if missing:
        sys.exit("no codepoint for: " + " ".join(missing))

    json.dump(found, open(sys.argv[3], "w"), sort_keys=True)
    open(sys.argv[4], "w").write(",".join("U+%04X" % p for p in sorted(found.values())))
  '';
in
  pkgs.runCommand "vjproj-icons" {} ''
    mkdir -p $out
    ${fonttools}/bin/python3 ${resolve} ${builtins.toJSON face} ${wanted} $out/icons.json points
    ${fonttools}/bin/python3 -m fontTools.subset ${builtins.toJSON face} \
      --unicodes="$(cat points)" \
      --layout-features= \
      --flavor=woff2 \
      --output-file=$out/icons.woff2

    echo "subset $(stat -c %s $out/icons.woff2) bytes for $(${fonttools}/bin/python3 -c \
      'import json,sys; print(len(json.load(open(sys.argv[1]))))' $out/icons.json) icons"
  ''
