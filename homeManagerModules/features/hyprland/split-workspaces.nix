{
  gcc13Stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  hyprland,
  pango,
  cairo,
}:
gcc13Stdenv.mkDerivation rec {
  name = "split-monitor-workspaces";
  pname = name;

  src = fetchFromGitHub {
    owner = "Duckonaut";
    repo = name;
    rev = "b6bc0c26c8ad9e08f5f29249f8511e6f01e92e09";
    hash = "sha256-uYDB0uXSgmEk2syJ9Et0q3RTIBtEHelcM6T8OT222fg";
  };

  BUILT_WITH_NOXWAYLAND = false;

  nativeBuildInputs = [meson ninja pkg-config];

  buildInputs =
    [
      hyprland
      pango
      cairo
    ]
    ++ hyprland.buildInputs;
}
