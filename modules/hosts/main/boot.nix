{
  hosts.main = {
    pkgs,
    config,
    ...
  }: {
    boot = {
      kernelPackages = pkgs.linuxPackages_latest;

      loader.grub.enable = true;
      loader.grub.efiSupport = true;
      loader.grub.efiInstallAsRemovable = true;

      supportedFilesystems.ntfs = true;

      kernelParams = ["quiet"];
      kernelModules = ["mt7921e" "coretemp" "cpuid" "v4l2loopback" "nct6687"];
      extraModulePackages = [config.boot.kernelPackages.nct6687d];
      blacklistedKernelModules = ["nct6683"];

      binfmt.emulatedSystems = ["aarch64-linux"];

      plymouth.enable = true;
    };

    programs.appimage.enable = true;
    programs.appimage.binfmt = true;
  };
}
