{
  flake.nixosModules.virt = {config, ...}: {
    users.users.${config.preferences.user.name}.extraGroups = ["libvirtd"];

    virtualisation.libvirtd.enable = true;

    programs.virt-manager.enable = true;

    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings = {
        dns_enabled = true;
      };
    };

    persistance.cache.directories = [
      "/var/lib/libvirt"
    ];
  };
}
