{
  pkgs,
  config,
  inputs,
  lib,
  ...
}: let
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec "$@"
  '';
in {
  hardware = {
    nvidia = {
      # package = config.boot.kernelPackages.nvidiaPackages.beta;
      # package = config.boot.kernelPackages.nvidiaPackages.vulkan_beta;
      # package = config.boot.kernelPackages.nvidiaPackages.production;

      package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "555.42.02";
        sha256_64bit = "sha256-k7cI3ZDlKp4mT46jMkLaIrc2YUx1lh1wj/J4SVSHWyk=";
        sha256_aarch64 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
        openSha256 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
        settingsSha256 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
        persistencedSha256 = lib.fakeSha256;
      };

      modesetting.enable = true;
      # prime = {
      #   # offload.enable = false; # on-demand
      #   # sync.enable = false; # always-on
      #   amdgpuBusId = "PCI:5:0:0";
      #   nvidiaBusId = "PCI:1:0:0";
      # };
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = false;
    };
  };

  # specialisation = {
  #   offload.configuration = {
  #     hardware.nvidia.prime.offload.enable = true;
  #   };
  #   sync.configuration = {
  #     hardware.nvidia.prime.sync.enable = true;
  #   };
  #   none.configuration = {
  #     hardware.nvidia.prime.sync.enable = lib.mkForce false;
  #     hardware.nvidia.prime.offload.enable = lib.mkForce false;
  #   };
  #   passthrough. configuration = {
  #       boot.extraModprobeConfig = "options vfio-pci ids=10de:2560,10de:228e";
  #       boot.kernelModules = ["kvm-intel" "wl" "vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio"];
  #       boot.kernelParams = ["amd_iommu=on" "intel_iommu=on"];
  #       boot.blacklistedKernelModules = ["nvidia" "nouveau"];
  #   };
  # };

  environment.systemPackages = with pkgs; [
    nvidia-offload
    pciutils
  ];

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  services.xserver.videoDrivers = ["nvidia"];

  # services.xserver = {
  #   # enable = true;
  #   videoDrivers = ["modesetting" "nvidia"];
  #
  #   windowManager.awesome = {
  #     enable = true;
  #     luaModules = with pkgs.luaPackages; [
  #       luarocks # is the package manager for Lua modules
  #       luadbi-mysql # Database abstraction layer
  #     ];
  #   };
  # };

}
