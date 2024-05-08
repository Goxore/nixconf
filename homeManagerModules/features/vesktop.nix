{pkgs, ...}: {
  home.packages = with pkgs; [
    vesktop
  ];

  myHomeManager.impermanence.cache.directories = [
    ".config/vesktop"
  ];

}
