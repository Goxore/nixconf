{
  modules.nixos.desktop = {
    services.upower.enable = true;

    security.polkit.enable = true;

    hardware = {
      enableAllFirmware = true;

      bluetooth.enable = true;
      bluetooth.powerOnBoot = true;

      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };

    persistence.directories = [
      "/var/lib/bluetooth"
    ];
  };
}
