{self, ...}: {
  devShells = pkgs: {
    vjcommon = self.lib.rustShell pkgs [];
  };
}
