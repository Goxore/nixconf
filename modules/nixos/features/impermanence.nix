{
  self,
  ...
}: {
  flake.nixosModules.impermanence = {config, ...}: {
    imports = [
      self.nixosModules.extra_impermanence
    ];

    persistance.enable = true;
    persistance.user = config.preferences.user.name;
  };
}
