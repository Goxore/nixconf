{
  wrappers.nh = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.nh;
    runShell = [''export NH_FLAKE="''${NH_FLAKE:-''${NIXCONF_ROOT:-$HOME/nixconf}}"''];
  };
}
