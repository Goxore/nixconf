{pkgs, ...}: {
  home.packages = with pkgs; [
    ungoogled-chromium
  ];

  myHomeManager.impermanence.directories = [
    ".config/chromium"
  ];
}
