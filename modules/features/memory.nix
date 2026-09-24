{
  modules.nixos.base = {
    systemd.oomd = {
      enableRootSlice = true;
      enableUserSlices = true;
    };

    zramSwap.enable = true;
  };
}
