{pkgs, ...}: {
  home.packages = with pkgs; [
    vesktop
  ];

  myHomeManager.impermanence.directories = [
    ".config/vesktop"
  ];

}
