{
  lib,
  osConfig ? {},
  ...
}: {
  config = lib.mkIf osConfig.myNixOS.virt-manager.enable {
    dconf.enable = lib.mkDefault true;

    dconf.settings = {
      "org/virt-manager/virt-manager/connections" = {
        autoconnect = ["qemu:///system"];
        uris = ["qemu:///system"];
      };
    };
  };
}
