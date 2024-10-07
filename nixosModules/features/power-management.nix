{...}: {

  boot.kernelParams = [ "amd_pstate=guided" ];

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "conservative";
  };

  services = {
    auto-cpufreq.enable = true;
  };
}
