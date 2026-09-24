{
  pkgs,
  icons,
  material,
  glyph,
}: let
  pillow = pkgs.python3.withPackages (python: [python.pillow]);

  face = "${pkgs.material-symbols}/share/fonts/truetype/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf";

  paint = pkgs.writeText "vjproj-paint-icon.py" ''
    import json, sys
    from PIL import Image, ImageDraw, ImageFont

    face, table, name, back, ink, out = sys.argv[1:7]
    point = json.load(open(table))[name]
    mark = chr(point)

    def draw(size, share, round_corners):
        pad = round(size * (1 - share) / 2)
        image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        pen = ImageDraw.Draw(image)
        if round_corners:
            pen.rounded_rectangle([0, 0, size - 1, size - 1], radius=round(size * 0.22), fill=back)
        else:
            pen.rectangle([0, 0, size - 1, size - 1], fill=back)
        font = ImageFont.truetype(face, size - 2 * pad)
        box = pen.textbbox((0, 0), mark, font=font)
        pen.text(
            ((size - box[2] - box[0]) / 2, (size - box[3] - box[1]) / 2),
            mark,
            font=font,
            fill=ink,
        )
        return image

    draw(192, 0.62, True).save(out + "/icon-192.png")
    draw(512, 0.62, True).save(out + "/icon-512.png")
    draw(512, 0.46, False).save(out + "/icon-mask.png")
  '';
in
  pkgs.runCommand "vjproj-appicon" {} ''
    mkdir -p $out
    ${pillow}/bin/python3 ${paint} \
      ${builtins.toJSON face} ${icons}/icons.json ${builtins.toJSON glyph} \
      ${builtins.toJSON material.primaryContainer} ${builtins.toJSON material.inkPrimaryContainer} $out
  ''
