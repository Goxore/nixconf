{self, ...}: {
  hosts.mini = {
    imports = [
      self.modules.nixos.base
      self.modules.nixos.desktop
      self.modules.nixos.personal

      self.modules.nixos.gaming
      self.modules.nixos.powersave
    ];

    networking.hostName = "mini";
    networking.networkmanager.enable = true;

    system.stateVersion = "25.11";
  };
}
