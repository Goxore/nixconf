{
  flake.nixosModules.powersave = {
    pkgs,
    lib,
    ...
  }: let
    cpuMaxFreq = 4600000;

    cpuFreqCap = pkgs.writeShellApplication {
      name = "cpu-freq-cap";

      runtimeInputs = [pkgs.coreutils];

      text = ''
        target="$1"

        for cpufreq in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
          [ -f "$cpufreq/scaling_max_freq" ] || continue

          if [ "$target" = "max" ]; then
            cat "$cpufreq/cpuinfo_max_freq" >"$cpufreq/scaling_max_freq"
          else
            printf '%s\n' "$target" >"$cpufreq/scaling_max_freq"
          fi
        done
      '';
    };
  in {
    services.tlp.enable = true;
    services.thermald.enable = true;

    powerManagement.powertop.enable = false;

    # Guard
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", DRIVER=="usbhid", TEST=="../power/control", ATTR{../power/control}="on"
    '';

    hardware.amdgpu.overdrive.enable = true;
    services.lact.enable = true;

    systemd.services.cpu-freq-cap = {
      description = "Cap CPU maximum frequency";
      after = ["tlp.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe cpuFreqCap} ${toString cpuMaxFreq}";
        ExecStop = "${lib.getExe cpuFreqCap} max";
      };
    };

    security.polkit.extraConfig = ''
      polkit.addRule(function (action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units"
          && action.lookup("unit") == "cpu-freq-cap.service"
          && subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';

    programs.gamemode.settings.custom = {
      start = "${lib.getExe' pkgs.systemd "systemctl"} stop cpu-freq-cap.service";
      end = "${lib.getExe' pkgs.systemd "systemctl"} start cpu-freq-cap.service";
    };

    # systemd.services.lact-monitor = {
    #   enable = true;
    #   description = "Monitor PowerProfiles and update LACT profile";
    #   after = ["network.target" "lactd.service" "power-profiles-daemon.service"];
    #   wants = ["lactd.service" "power-profiles-daemon.service"];
    #   serviceConfig = {
    #     Type = "simple";
    #     ExecStartPre = lib.getExe (pkgs.writeShellApplication {
    #       name = "lact-initial-set";
    #       runtimeInputs = [pkgs.lact pkgs.glib pkgs.dbus pkgs.power-profiles-daemon];
    #       text = ''
    #         profile=$(powerprofilesctl get)
    #         if [[ $profile == "power-saver" ]]; then
    #             lact cli profile set "power-saver"
    #         else
    #             lact cli profile set "default"
    #         fi
    #       '';
    #     });
    #     ExecStart = lib.getExe (pkgs.writeShellApplication {
    #       name = "lact-watcher";
    #       runtimeInputs = [pkgs.libnotify pkgs.lact pkgs.glib pkgs.dbus];
    #       text = ''
    #         gdbus monitor --system --dest net.hadess.PowerProfiles |
    #         while read -r line; do
    #             if [[ $line =~ ActiveProfile ]]; then
    #                 profile=$(echo "$line" | grep -oP "(?<=<').+?(?='>)")
    #
    #                 if [[ $profile == "power-saver" ]]; then
    #                     lact cli profile set "power-saver"
    #                 else
    #                     lact cli profile set "default"
    #                 fi
    #             fi
    #         done
    #       '';
    #     });
    #     Restart = "always";
    #     User = "root";
    #   };
    #   wantedBy = ["multi-user.target"];
    # };
  };
}
