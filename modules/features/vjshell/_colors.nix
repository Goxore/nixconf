theme: let
  inherit (builtins) attrNames concatStringsSep sort;

  names = sort (a: b: a < b) (attrNames theme);

  property = name: "    readonly property color ${name}: \"${theme.${name}}\"";
in
  concatStringsSep "\n" ([
      "pragma Singleton"
      ""
      "import QtQuick"
      "import Quickshell"
      ""
      "Singleton {"
    ]
    ++ (map property names)
    ++ [
      "}"
      ""
    ])
