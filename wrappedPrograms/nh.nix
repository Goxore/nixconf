{
  flake.wrappers.nh = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.nh;
    env.NH_FLAKE = "nixconf";
  };
}
