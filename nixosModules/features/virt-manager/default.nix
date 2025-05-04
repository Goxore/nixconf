{config, ...}: {
  programs.virt-manager.enable = true;

  users.groups.libvirtd.members = builtins.attrNames config.myNixOS.home-users;

  virtualisation.libvirtd.enable = true;

  virtualisation.spiceUSBRedirection.enable = true;

  myNixOS.impermanence.directories = [
    "/var/lib/libvirt"
  ];
}
