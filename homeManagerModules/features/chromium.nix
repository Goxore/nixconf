{pkgs, ...}: {
  home.packages = with pkgs; [
    ungoogled-chromium
  ];

  myHomeManager.impermanence.cache.directories = [
    ".config/chromium"
  ];
}
