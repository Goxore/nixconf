{pkgs, lib, ...}: let
  sddmTheme = import ./sddm-theme.nix {inherit pkgs;};
in {
  services.xserver = {
    enable = true;
    displayManager = {
      sddm.enable = lib.mkDefault true;
      sddm.theme = "${sddmTheme}";
    };
  };

  environment.systemPackages = with pkgs; [
    libsForQt5.qt5.qtquickcontrols2
    libsForQt5.qt5.qtgraphicaleffects
  ];
}
