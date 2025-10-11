{self, ...}: {
  flake.nixosModules.general = {
    pkgs,
    config,
    ...
  }: {
    imports = [
      self.nixosModules.extra_hjem
      self.nixosModules.gtk
      self.nixosModules.nix
    ];

    users.users.${config.preferences.user.name} = {
      isNormalUser = true;
      description = "${config.preferences.user.name}'s account";
      extraGroups = ["wheel" "networkmanager"];
      shell = self.packages.${pkgs.system}.environment;

      hashedPasswordFile = "/persist/passwd";
      initialPassword = "12345";
    };

    persistance.data.directories = [
      "nixconf"

      "Videos"
      "Documents"
      "Projects"

      ".ssh"
    ];

    # todo: remove
    persistance.cache.directories = [
      ".local/share/nvim"
      ".local/share/fish"
      ".config/nvim"
    ];
  };
}
