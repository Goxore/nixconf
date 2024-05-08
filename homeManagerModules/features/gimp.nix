{pkgs, ...}: {
  home.packages = with pkgs; [
    gimp
  ];

  myHomeManager.impermanence.cache.directories = [
    ".config/GIMP"
  ];

}
