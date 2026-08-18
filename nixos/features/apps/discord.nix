{self, ...}: {
  flake.nixosModules.discord = {pkgs, ...}: let
    selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
  in {
    environment.systemPackages = [
      selfpkgs.vesktop
      selfpkgs.vesktop-alt
      pkgs.discord
    ];

    persistance.cache.directories = [
      ".config/vesktop"
      ".config/vesktop-alt"
    ];
  };
}
