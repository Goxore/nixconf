{inputs, ...}: {
  flake.nixosModules.extra_impermanence = {
    lib,
    config,
    ...
  }: let
    inherit
      (lib)
      mkIf
      mkDefault
      mkAfter
      ;
    cfg = config.persistance;
  in {
    imports = [
      inputs.impermanence.nixosModules.impermanence
    ];

    config = mkIf cfg.enable {
      fileSystems."/persist".neededForBoot = true;

      programs.fuse.userAllowOther = true;

      boot.tmp.cleanOnBoot = mkDefault true;

      environment.persistence = {
        # "/persist/userdata".users = persistentData;
        # "/persist/usercache".users = persistentCache;

        "/persist/userdata".users."${cfg.user}" = {
          directories = cfg.data.directories;
          files = cfg.data.files;
        };

        "/persist/usercache".users."${cfg.user}" = {
          directories = cfg.cache.directories;
          files = cfg.cache.files;
        };

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
              "/tmp"
              # {
              #   directory = "/var/lib/colord";
              #   user = "colord";
              #   group = "colord";
              #   mode = "u=rwx,g=rx,o=";
              # }
            ]
            ++ cfg.directories;
          files =
            [
              "/etc/machine-id"
              "/etc/lact/config.yaml"
              {
                file = "/var/keys/secret_file";
                parentDirectory = {mode = "u=rwx,g=,o=";};
              }
            ]
            ++ cfg.files;
        };
      };

      boot.initrd.postDeviceCommands =
        mkIf cfg.nukeRoot.enable
        (mkAfter ''
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
  };
}
