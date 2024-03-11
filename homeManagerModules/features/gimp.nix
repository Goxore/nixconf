{pkgs, ...}: {
  home.packages = with pkgs; [
    gimp
  ];

  myHomeManager.impermanence.directories = [
    ".config/GIMP"
  ];

}
