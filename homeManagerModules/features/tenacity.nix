{pkgs, ...}: {
  home.packages = with pkgs; [
    tenacity
  ];

  myHomeManager.impermanence.cache.directories = [
    ".config/tenacity"
  ];

}
