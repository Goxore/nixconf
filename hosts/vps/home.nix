{
  inputs,
  outputs,
  pkgs,
  lib,
  ...
}: {
  imports = [outputs.homeManagerModules.default];

  myHomeManager = {
    bundles.general.enable = true;
  };

  home = {
    username = "main";
    stateVersion = "22.11";

    packages = with pkgs; [];
  };
}
