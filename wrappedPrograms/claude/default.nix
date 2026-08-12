{
  self,
  lib,
  ...
}: {
  flake.wrappers.claude = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.wrapperModules.claude-code];

    binName = "claude";
    env.__NIXOS_SET_ENVIRONMENT_DONE = "1";
    runShell = [(self.lib.vjenv.tool pkgs "claude")];

    settings.statusLine = {
      type = "command";
      command = "${lib.getExe pkgs.bun} run ${./statusline.ts}";
    };
  };
}
