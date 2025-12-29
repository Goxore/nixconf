{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.mini = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.hostMini
    ];
  };

  flake.nixosModules.hostMini = {pkgs, ...}: {
    imports = [
      self.nixosModules.base
      self.nixosModules.general
      self.nixosModules.desktop

      self.nixosModules.discord
      self.nixosModules.gimp
      self.nixosModules.hyprland
      self.nixosModules.telegram
      self.nixosModules.youtube-music

      self.nixosModules.powersave
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "mini";

    networking.networkmanager.enable = true;

    home.programs.hyprland.settings = {
      monitor = [
        "eDP-1,1920x1080@60,0x0,0.833333"
      ];
    };

    system.stateVersion = "24.05";
  };
}
