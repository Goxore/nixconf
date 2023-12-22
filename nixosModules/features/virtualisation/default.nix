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
    myNixOS.virtualisation.enable = lib.mkDefault true;

    virtualisation.vmVariant = {
      myNixOS.sharedSettings.altIsSuper = true;
      virtualisation.qemu.options = [
        "-device virtio-vga-gl"
        "-display sdl,gl=on,show-cursor=off"
        "-audio pa,model=hda"
      ];
    };
  };
}
