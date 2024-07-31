{
  pkgs,
  lib,
  config,
  ...
}: {
  programs.imv = {
    enable = true;
    settings = {
      options.background = "${config.stylix.base16Scheme.base00}";
    };
  };
}
