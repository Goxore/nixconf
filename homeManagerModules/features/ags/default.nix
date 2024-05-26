{
  pkgs,
  inputs,
  ...
}: {
  imports = [inputs.ags.homeManagerModules.default];

  programs.ags = {
    enable = true;

    configDir = ./.;

    extraPackages = with pkgs; [
      bun
    ];
  };

  home.packages = with pkgs; [
    bun
  ];

}
