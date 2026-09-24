{inputs, ...}: {
  modules.nixos.impermanence = {
    lib,
    config,
    ...
  }: let
    cfg = config.persistence;
  in {
    imports = [
      inputs.impermanence.nixosModules.impermanence
    ];

    config = lib.mkIf cfg.enable {
      fileSystems."/persist".neededForBoot = true;

      programs.fuse.userAllowOther = true;

      boot.tmp.cleanOnBoot = lib.mkDefault true;

      environment.persistence = {
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
              "/var/lib/nixos"
              "/var/lib/systemd/coredump"
              "/etc/NetworkManager/system-connections"
              "/tmp"
            ]
            ++ cfg.directories;
          files =
            [
              "/etc/machine-id"
              {
                file = "/var/keys/secret_file";
                parentDirectory = {mode = "u=rwx,g=,o=";};
              }
            ]
            ++ cfg.files;
        };
      };
    };
  };
}
