{
  pkgs,
  lib,
  inputs,
  config,
  ...
}: let
  cfg = config.myNixOS.impermanence;
in {
  imports = [
    inputs.impermanence.nixosModules.impermanence
    inputs.persist-retro.nixosModules.persist-retro
  ];

  options.myNixOS.impermanence = {
    nukeRoot.enable = lib.mkEnableOption "Destroy /root on every boot";

    volumeGroup = lib.mkOption {
      default = "btrfs_vg";
      description = ''
        Btrfs volume group name
      '';
    };

    directories = lib.mkOption {
      default = [];
      description = ''
        directories to persist
      '';
    };
  };

  config = {
    fileSystems."/persist".neededForBoot = true;
    programs.fuse.userAllowOther = true;

    environment.persistence = let
      persistentData = builtins.mapAttrs (name: user: {
        directories = config.home-manager.users."${name}".myHomeManager.impermanence.data.directories;
        files = config.home-manager.users."${name}".myHomeManager.impermanence.data.files;
      }) (config.myNixOS.home-users);
      persistentCache = builtins.mapAttrs (name: user: {
        directories = config.home-manager.users."${name}".myHomeManager.impermanence.cache.directories;
        files = config.home-manager.users."${name}".myHomeManager.impermanence.cache.files;
      }) (config.myNixOS.home-users);
    in {
      "/persist/userdata".users = persistentData;
      "/persist/usercache".users = persistentCache;
      "/persist/system" = {
        hideMounts = true;
        directories =
          [
            "/etc/nixos"
            "/var/log"
            "/var/lib/bluetooth"
            "/var/lib/nixos"
            "/var/lib/systemd/coredump"
            "/etc/NetworkManager/system-connections"
            {
              directory = "/var/lib/colord";
              user = "colord";
              group = "colord";
              mode = "u=rwx,g=rx,o=";
            }
          ]
          ++ cfg.directories;
        files = [
          "/etc/machine-id"
          {
            file = "/var/keys/secret_file";
            parentDirectory = {mode = "u=rwx,g=,o=";};
          }
        ];
      };
    };

    boot.initrd.postDeviceCommands =
      lib.mkIf cfg.nukeRoot.enable
      (lib.mkAfter ''
        mkdir /btrfs_tmp
        mount /dev/${cfg.volumeGroup}/root /btrfs_tmp
        if [[ -e /btrfs_tmp/root ]]; then
            mkdir -p /btrfs_tmp/old_roots
            timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
            mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
        fi

        delete_subvolume_recursively() {
            IFS=$'\n'
            for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
                delete_subvolume_recursively "/btrfs_tmp/$i"
            done
            btrfs subvolume delete "$1"
        }

        for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
            delete_subvolume_recursively "$i"
        done

        btrfs subvolume create /btrfs_tmp/root
        umount /btrfs_tmp
      '');
  };
}
