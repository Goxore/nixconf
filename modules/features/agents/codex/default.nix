{
  self,
  lib,
  wrapperModules,
  ...
}: {
  wrappers.codex = {
    wlib,
    pkgs,
    ...
  }: let
    vjprojExe = lib.getExe pkgs.vj.vjproj;

    hooks = pkgs.writeText "vjproj-codex-hooks.json" (builtins.toJSON {
      hooks =
        self.lib.agentHooks pkgs
        // {
          PermissionRequest = [(self.lib.agentHook "${vjprojExe} agent report --activity blocked")];
        };
    });
  in {
    imports = [wlib.modules.default wrapperModules._agent];

    package = pkgs.codex;

    agent = {
      kind = "codex";
      configVar = "CODEX_HOME";
    };

    runShell = [
      ''${pkgs.coreutils}/bin/install -Dm644 ${hooks} "$CODEX_HOME/hooks.json"''
    ];
  };
}
