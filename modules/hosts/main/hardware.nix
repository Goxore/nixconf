{
  hosts.main = {
    imports = [
      ./_scan.nix
    ];

    programs.corectrl.enable = true;

    hardware.cpu.amd.updateMicrocode = true;
    hardware.graphics.enable = true;

    hardware.amdgpu.overdrive.enable = true;
    services.lact.enable = true;

    services.hardware.openrgb.enable = true;

    services.xserver.videoDrivers = ["amdgpu"];
    boot.initrd.kernelModules = ["amdgpu"];

    powersave.cpuMaxFreq = 4600000;
  };
}
