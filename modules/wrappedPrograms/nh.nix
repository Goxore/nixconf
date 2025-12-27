{inputs, ...}: let
in {
  perSystem = {pkgs, ...}: {
    packages.nh = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.nh;
      env = {
        "NH_FLAKE" = "/home/yurii/nixconf";
      };
    };
  };
}
