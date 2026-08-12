{self, ...}: {
  flake.nixosModules.godot = {pkgs, ...}: {
    environment.systemPackages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.godot
    ];

    persistance.cache.directories = [
      ".config/godot"
    ];
  };
}
