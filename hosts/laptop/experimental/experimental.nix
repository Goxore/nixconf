{
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
  ];

  # ================================================================ #
  # =                          MINECRAFT                           = #
  # ================================================================ #

  # services.minecraft-server.enable = true;
  # services.minecraft-server.eula = true;
  # services.minecraft-server = {
  #   enable = true;
  #   eula = true;
  #   declarative = true;
  # };

  nixpkgs.overlays = [inputs.nix-minecraft.overlay];

  services.minecraft-servers = {
    enable = false;
    eula = true;
    servers.cool-modpack = {
      enable = true;
      # package = pkgs.fabricServers.fabric-1_18_2.override {loaderVersion = "0.14.9";};
      # package = pkgs.callPackage ./default.nix {
      #   jdk = pkgs.jdk21;
      #   # version = "1.20.1-47.3.1";
      #   version = "1.21-51.0.29";
      #   # version = "1.20.6-50.1.0";
      #   # version = "1.19.4-45.0.0";
      #   # hash = "sha256-DRzLUVL56wnl2SBemSmXCYtHysI42yYB8WF7GEFnMjA=";
      #   hash = "sha256-FYLv5X995koMDR8IQNe6NXTjtzjKFGAYN1pybi9kjX0=";
      #   # hash = "sha256-dSXD2cWWRq673Ih2qvIevpuftcG91lIIdSAsd0Yf9Ms=";
      # };
    };
  };

  # services.minecraft-server.package = pkgs.callPackage ./default.nix {
  #   version = "1.20.1-47.3.1";
  # };

  # ================================================================ #
  # =                            WIVRN                             = #
  # ================================================================ #

  services.wivrn = {
    enable = false;
    openFirewall = true;

    # Write information to /etc/xdg/openxr/1/active_runtime.json, VR applications
    # will automatically read this and work with wivrn
    defaultRuntime = true;

    # Executing it through the systemd service executes WiVRn w/ CAP_SYS_NICE
    # Resulting in no stutters!
    autoStart = true;

    # Config for WiVRn (https://github.com/WiVRn/WiVRn/blob/master/docs/configuration.md)
    config = {
      enable = true;
      json = {
        # 1.0x display scaling
        scale = 1.0;
        # 300 mbs
        bitrate = 100000000;
        encoders = [
          {
            # encoder = "vaapi";
            # codec = "h265";
            # 1.0 x 1.0 scaling
            width = 1.0;
            height = 1.0;
            offset_x = 0.0;
            offset_y = 0.0;
          }
        ];
      };
    };
  };
}
