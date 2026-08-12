{self, ...}: {
  flake.wrappers.gh = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.gh;
    runShell = [(self.lib.vjenv.gated pkgs "gh")];
  };

  flake.wrappers.codex = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.codex;
    binName = "codex";
    env.__NIXOS_SET_ENVIRONMENT_DONE = "1";
    runShell = [(self.lib.vjenv.tool pkgs "codex")];
  };
}
