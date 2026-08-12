{self, ...}: {
  flake.wrappers.which-key = {...}: {
    settings = {
      font = "JetBrainsMono Nerd Font 12";
      background = self.theme.base00;
      color = self.theme.base06;
      border = self.theme.base0F;
      separator = " ➜ ";
      border_width = 2;
      corner_r = 15;
      padding = 15;
      rows_per_column = 5;
      column_padding = 25;

      anchor = "bottom-right";
      margin_right = 0;
      margin_bottom = 5;
      margin_left = 5;
      margin_top = 0;
    };
  };

  flake.wrappers.menu1 = {
    wlib,
    pkgs,
    lib,
    ...
  }: let
    vjshellExe = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.vjshell;
  in {
    imports = [
      wlib.wrapperModules.wlr-which-key
      self.wrapperModules.which-key
    ];

    settings.menu = [
      {
        key = "b";
        desc = "Bluetooth";
        cmd = "${vjshellExe} ipc call bluetooth toggle";
      }
      {
        key = "w";
        desc = "Wifi";
        cmd = "${vjshellExe} ipc call wifi toggle";
      }
      {
        key = "n";
        desc = "Notifications";
        cmd = "${vjshellExe} ipc call notifications toggle";
      }
      {
        key = "f";
        desc = "Firefox";
        cmd = "firefox";
      }
      {
        key = "t";
        desc = "Telegram";
        cmd = "Telegram";
      }
      {
        key = "d";
        desc = "Discord";
        cmd = "vesktop";
      }
      {
        key = "D";
        desc = "Discord (alt)";
        cmd = "vesktop-alt";
      }
      {
        key = "m";
        desc = "Youtube Music";
        cmd = "pear-desktop";
      }
      {
        key = "s";
        desc = "Pavucontrol";
        cmd = "${lib.getExe pkgs.pavucontrol}";
      }
    ];
  };
}
