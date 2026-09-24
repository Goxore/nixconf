{
  modules.nixos.desktop = {
    pkgs,
    lib,
    ...
  }: {
    environment.systemPackages = [pkgs.vj.vjshellDynamic];

    systemd.user.services.vjshell = {
      enableDefaultPath = false;
      partOf = ["graphical-session.target"];
      after = ["graphical-session.target"];

      serviceConfig = {
        ExecStart = lib.getExe pkgs.vj.vjshellDynamic;
        Restart = "on-failure";
        RestartSec = 2;
        KillMode = "process";
      };
    };

    persistence.cache.directories = [
      ".local/state/quickshell"
      ".cache/vjshell"
    ];
  };
}
