{
  flake.wrappers.qalc = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.libqalculate;
    addFlag = ["-s" "autocalc" "-s" "decimal comma off"];
  };
}
