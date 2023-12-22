{
  pkgs,
  config,
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
      # forceFullCompositionPipeline = true;
      modesetting.enable = true;
      prime = {
        offload.enable = false; # on-demand
        # sync.enable = false; # always-on
        amdgpuBusId = "PCI:5:0:0";
        nvidiaBusId = "PCI:1:0:0";
      };
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.beta;
    };
  };

  boot = {
    extraModulePackages = [
      config.boot.kernelPackages.nvidia_x11
    ];
  };

  environment.systemPackages = with pkgs; [
    nvidia-offload
    pciutils
  ];

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  services.xserver = {
    enable = true;

    windowManager.awesome = {
      enable = true;
      luaModules = with pkgs.luaPackages; [
        luarocks # is the package manager for Lua modules
        luadbi-mysql # Database abstraction layer
      ];
    };
  };

  specialisation = {
    # passthrough = {
    #   configuration = {
    #     boot.extraModprobeConfig = "options vfio-pci ids=10de:2560,10de:228e";
    #     boot.kernelModules = ["kvm-intel" "wl" "vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio"];
    #     boot.kernelParams = ["amd_iommu=on" "intel_iommu=on"];
    #     boot.blacklistedKernelModules = ["nvidia" "nouveau"];
    #   };
    # };
  };
}
