{
  pkgs,
  inputs,
  config,
  ...
}: {
  imports = [
    inputs.prism.homeModules.prism
  ];

  prism = {
    enable = true;
    wallpapers = ./wallpapers;
    outPath = ".local/share/wallpapers";

    colorscheme = config.colorscheme or "gruvbox-dark";
  };
}
