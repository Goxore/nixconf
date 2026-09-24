{
  self,
  lib,
  wrapperModules,
  ...
}: let
  mkClaude = flavour: {
    wlib,
    pkgs,
    ...
  }: let
    vjprojExe = lib.getExe pkgs.vj.vjproj;
  in {
    imports = [wlib.wrapperModules.claude-code wrapperModules._agent];

    package = pkgs.claude-code.override {
      manifest = lib.importJSON ./manifest.json;
    };

    agent = {
      kind = flavour;
      configVar = "CLAUDE_CONFIG_DIR";
      instructions = "CLAUDE.md";
    };

    settings.statusLine = {
      type = "command";
      command = "${lib.getExe pkgs.bun} run ${./statusline.ts}";
    };

    settings.hooks =
      self.lib.agentHooks pkgs
      // {
        Notification = [(self.lib.agentHook "${vjprojExe} agent notify")];
        StopFailure = [(self.lib.agentHook "${vjprojExe} agent report --activity idle")];
      };
  };
in {
  wrappers.claude-per = mkClaude "claude-per";
  wrappers.claude-fish = mkClaude "claude-fish";
}
