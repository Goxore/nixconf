{
  lib,
  self,
  ...
}: {
  checks = pkgs: let
    dynamicMango = pkgs.vj.mangowcDynamic.apply {};
    staticMango = pkgs.vj.mangowc.apply {};
    rebuiltShell = pkgs.vj.vjshellDynamic.wrap {
      env.VJSHELL_TEST_GENERATION = "next";
    };
  in {
    dynamic-mode = assert builtins.elem "/etc/mango/config.conf" (lib.toList dynamicMango.flags."-c".data);
    assert lib.hasInfix "NIXCONF_ROOT" dynamicMango.autostart_sh;
    assert lib.hasInfix "restart vjshell.service" dynamicMango.autostart_sh;
    assert !(lib.hasInfix "restart vjshell.service" staticMango.autostart_sh);
    assert lib.hasInfix (builtins.unsafeDiscardStringContext "${lib.getExe pkgs.vj.vjshell} &") staticMango.autostart_sh;
      pkgs.runCommand "dynamic-mode-check" {
        nativeBuildInputs = [pkgs.dbus];
        dynamicShell = lib.getExe pkgs.vj.vjshellDynamic;
        rebuiltShell = lib.getExe rebuiltShell;
        dynamicEditor = lib.getExe pkgs.vj.neovimDynamic;
        staticEditor = lib.getExe pkgs.vj.neovim;
        colors = self.lib.vjshellColors pkgs;
      } ''
        ${self.lib.sandboxHome "$TMPDIR"}
        dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- \
          bash ${./_dynamic-mode-tests.sh}
        touch "$out"
      '';
  };
}
