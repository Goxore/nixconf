{
  config,
  lib,
  ...
}: let
  cfg = config.myNixOS;
in {
  options.myNixOS = {
    sharedSettings = {
      altIsSuper = lib.mkEnableOption "switch super to alt";
    };
  };

  config = {
    virtualisation.vmVariant = {
      myNixOS.sharedSettings.altIsSuper = true;
      services.sshd.enable = true;
      virtualisation = {
        memorySize = 4096;
        cores = 4;
        qemu.options = [
          "-device virtio-vga-gl"
          "-display sdl,gl=on,show-cursor=off"
          "-audio pa,model=hda"
        ];
        sharedDirectories = {
          primary = {
            source = "/mnt/shared";
            target = "/mnt/shared";
          };
        };
      };
    };
  };
}
