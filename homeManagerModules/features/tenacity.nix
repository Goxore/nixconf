{pkgs, ...}: {
  home.packages = with pkgs; [
    tenacity
  ];

  myHomeManager.impermanence.directories = [
    ".config/tenacity"
  ];

}
