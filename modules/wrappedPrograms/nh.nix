{inputs, ...}: let
in {
  perSystem = {pkgs, ...}: {
    packages.nh = inputs.wrappers.lib.makeWrapper {
      inherit pkgs;
      package = pkgs.nh;
      env = {
        "NH_FLAKE" = "/home/yurii/nixconf";
      };
    };
  };
}
