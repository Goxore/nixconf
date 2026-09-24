{
  inputs,
  self,
  ...
}: {
  hosts.main = {pkgs, ...}: {
    imports = [
      self.modules.nixos.base
      self.modules.nixos.desktop
      self.modules.nixos.personal

      self.modules.nixos.impermanence

      self.modules.nixos.gaming
      self.modules.nixos.vr
      self.modules.nixos.powersave

      self.modules.nixos.virt
      self.modules.nixos.obs

      inputs.disko.nixosModules.disko
      self.diskoConfigurations.main
    ];

    networking.hostName = "main";

    environment.systemPackages = [
      pkgs.winetricks
      pkgs.glib

      pkgs.bs-manager

      pkgs.android-tools
    ];

    services = {
      flatpak.enable = true;
      udisks2.enable = true;
      printing.enable = true;
    };

    persistence.files = [
      "/etc/lact/config.yaml"
    ];

    system.stateVersion = "23.11";
  };
}
