{
  flake.nixosModules.powersave = {
    pkgs,
    lib,
    ...
  }: let
    inherit (lib) getExe getExe';
  in {
    services.power-profiles-daemon.enable = true;

    hardware.amdgpu.overdrive.enable = true;
    services.lact.enable = true;

    systemd.services.lact-monitor = {
      enable = true;
      description = "Monitor PowerProfiles and update LACT profile";
      after = ["network.target" "lactd.service" "power-profiles-daemon.service"];
      wants = ["lactd.service" "power-profiles-daemon.service"];
      serviceConfig = {
        Type = "simple";
        ExecStartPre = getExe (pkgs.writeShellApplication {
          name = "lact-initial-set";
          runtimeInputs = [pkgs.lact pkgs.glib pkgs.dbus pkgs.power-profiles-daemon];
          text = ''
            profile=$(powerprofilesctl get)
            if [[ $profile == "power-saver" ]]; then
                lact cli profile set "power-saver"
            else
                lact cli profile set "default"
            fi
          '';
        });
        ExecStart = getExe (pkgs.writeShellApplication {
          name = "lact-watcher";
          runtimeInputs = [pkgs.libnotify pkgs.lact pkgs.glib pkgs.dbus];
          text = ''
            gdbus monitor --system --dest net.hadess.PowerProfiles |
            while read -r line; do
                if [[ $line =~ ActiveProfile ]]; then
                    profile=$(echo "$line" | grep -oP "(?<=<').+?(?='>)")

                    if [[ $profile == "power-saver" ]]; then
                        lact cli profile set "power-saver"
                    else
                        lact cli profile set "default"
                    fi
                fi
            done
          '';
        });
        Restart = "always";
        User = "root";
      };
      wantedBy = ["multi-user.target"];
    };
  };
}
