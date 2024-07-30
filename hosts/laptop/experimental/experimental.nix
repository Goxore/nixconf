{
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers

    "${inputs.nixpkgs-wivrn}/nixos/modules/services/video/wivrn.nix"
  ];

  # ================================================================ #
  # =                          MINECRAFT                           = #
  # ================================================================ #

  # services.minecraft-server.enable = true;
  # services.minecraft-server.eula = true;

  nixpkgs.overlays = [inputs.nix-minecraft.overlay];

  services.minecraft-servers = {
    enable = true;
    eula = true;
    servers.cool-modpack = {
      enable = true;
      # package = pkgs.fabricServers.fabric-1_18_2.override {loaderVersion = "0.14.9";};
      package = pkgs.callPackage ./default.nix {
        jdk = pkgs.jdk21;
        # version = "1.20.1-47.3.1";
        version = "1.21-51.0.29";
        # version = "1.20.6-50.1.0";
        # version = "1.19.4-45.0.0";
        # hash = "sha256-DRzLUVL56wnl2SBemSmXCYtHysI42yYB8WF7GEFnMjA=";
        hash = "sha256-FYLv5X995koMDR8IQNe6NXTjtzjKFGAYN1pybi9kjX0=";
        # hash = "sha256-dSXD2cWWRq673Ih2qvIevpuftcG91lIIdSAsd0Yf9Ms=";
      };
    };
  };

  # services.minecraft-server.package = pkgs.callPackage ./default.nix {
  #   version = "1.20.1-47.3.1";
  # };

  # ================================================================ #
  # =                            WIVRN                             = #
  # ================================================================ #

  services.wivrn = {
    package =
      (import inputs.nixpkgs-wivrn {
        system = "${pkgs.system}";
        config = {allowUnfree = true;};
      })
      .wivrn;
    # package = inputs.nixpkgs-wivrn.legacyPackages.${pkgs.system}.wivrn;
    enable = true;
    openFirewall = true;
    defaultRuntime = true;
    highPriority = true;
  };
}
