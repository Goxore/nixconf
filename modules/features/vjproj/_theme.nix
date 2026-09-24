{
  ansi,
  material,
}: let
  inherit (builtins) attrNames concatStringsSep elemAt genList replaceStrings sort toString;

  upper = ["A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z"];

  lower = ["a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z"];

  kebab = replaceStrings upper (map (letter: "-" + letter) lower);

  var = name: value: "  --${name}: ${value};";

  roles = sort (a: b: a < b) (attrNames material);
in
  concatStringsSep "\n" (
    [":root {"]
    ++ map (name: var (kebab name) material.${name}) roles
    ++ genList (i: var "ansi-${toString i}" (elemAt ansi i)) 16
    ++ [
      "}"
      ""
    ]
  )
