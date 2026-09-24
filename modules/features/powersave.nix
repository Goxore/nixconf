{
  modules.nixos.powersave = {
    pkgs,
    lib,
    config,
    ...
  }: let
    cfg = config.powersave;

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
    options.powersave.cpuMaxFreq = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = ''
        Ceiling in kHz for every core's scaling_max_freq, or null to leave the
        governor alone. The usable value is a property of the installed CPU, so
        the host sets it rather than this profile.
      '';
    };

    config = lib.mkMerge [
      {
        services.tlp.enable = true;
        services.thermald.enable = true;

        powerManagement.powertop.enable = false;

        services.udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="usb", DRIVER=="usbhid", TEST=="../power/control", ATTR{../power/control}="on"
        '';
      }

      (lib.mkIf (cfg.cpuMaxFreq != null) {
        systemd.services.cpu-freq-cap = {
          description = "Cap CPU maximum frequency";
          after = ["tlp.service"];
          wantedBy = ["tlp.service"];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${lib.getExe cpuFreqCap} ${toString cfg.cpuMaxFreq}";
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
      })
    ];
  };
}
