{
  flake.nixosModules.base = {lib, ...}: let
    inherit
      (lib)
      mkEnableOption
      mkOption
      ;
  in {
    options.persistance = {
      enable = mkEnableOption "enable persistance";

      nukeRoot.enable = mkEnableOption "Destroy /root on every boot";

      volumeGroup = mkOption {
        default = "btrfs_vg";
        description = ''
          Btrfs volume group name
        '';
      };

      user = mkOption {
        default = "username";
        description = ''
          Main user
        '';
      };

      directories = mkOption {
        default = [];
        description = ''
          directories to persist
        '';
      };

      files = mkOption {
        default = [];
        description = ''
          files to persist
        '';
      };

      data.directories = mkOption {
        default = [];
        description = ''
          directories to persist
        '';
      };

      data.files = mkOption {
        default = [];
        description = ''
          files to persist
        '';
      };

      cache.directories = mkOption {
        default = [];
        description = ''
          directories to persist
        '';
      };

      cache.files = mkOption {
        default = [];
        description = ''
          files to persist
        '';
      };
    };
  };
}
