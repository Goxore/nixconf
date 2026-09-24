{lib, ...}: {
  lib.dynamicExe = dynamicMode: package: let
    exe = lib.getExe package;
  in
    if dynamicMode
    then "/run/current-system/sw/bin/${baseNameOf exe}"
    else exe;

  wrappers._dynamic = {
    lib,
    config,
    ...
  }: {
    options.dynamicMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        If true, resolve live paths instead of store paths for fast edits

        Both versions of the package may be installed simultaneously
      '';
    };

    config.runShell = lib.mkIf config.dynamicMode (lib.mkBefore [
      ''export NIXCONF_ROOT="''${NIXCONF_ROOT:-$HOME/nixconf}"''
    ]);
  };
}
