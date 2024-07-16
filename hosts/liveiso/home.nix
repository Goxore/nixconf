{
  inputs,
  outputs,
  pkgs,
  lib,
  ...
}: {
  myHomeManager = {
    bundles.general.enable = true;
  };

  home = {
    stateVersion = "22.11";
    homeDirectory = lib.mkDefault "/home/yurii";
    username = "yurii";

    packages = with pkgs; [];
  };
}
