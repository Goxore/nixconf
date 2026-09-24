{self, ...}: {
  modules.nixos.desktop = {
    console.colors = self.lib.ansiNoHash;
  };
}
