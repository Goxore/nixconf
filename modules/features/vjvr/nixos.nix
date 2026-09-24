{self, ...}: {
  modules.nixos.vr = {
    config,
    pkgs,
    lib,
    ...
  }: let
    user = config.preferences.user.name;
    inherit (self.lib) theme;
    apk = pkgs.fetchurl {
      url = "https://github.com/WiVRn/WiVRn/releases/download/v${config.services.wivrn.package.version}/WiVRn-release.apk";
      hash = "sha256-HfZknsdyJPzIIa8KtIlyIr3z1+ts5q1jZGEzZyQREzE=";
    };
    apkHash = builtins.convertHash {
      hash = apk.outputHash;
      toHashFormat = "base16";
    };
    desktop = pkgs.writeShellScript "vjvr-desktop" ''
      ${pkgs.procps}/bin/pkill -TERM -x wayvr || true
      for _ in 1 2 3 4 5; do
        if ! ${pkgs.procps}/bin/pgrep -x wayvr >/dev/null; then
          break
        fi
        ${pkgs.coreutils}/bin/sleep 1
      done
      ${pkgs.procps}/bin/pkill -KILL -x wayvr || true
      exec ${lib.getExe pkgs.wayvr} --replace --openxr --show --wait
    '';
    touchBindings = {
      pose = {
        left = "/user/hand/left/input/aim/pose";
        right = "/user/hand/right/input/aim/pose";
      };
      haptic = {
        left = "/user/hand/left/output/haptic";
        right = "/user/hand/right/output/haptic";
      };
      click = {
        left = "/user/hand/left/input/trigger/value";
        right = "/user/hand/right/input/trigger/value";
      };
      grab = {
        left = "/user/hand/left/input/squeeze/value";
        right = "/user/hand/right/input/squeeze/value";
      };
      scroll = {
        left = "/user/hand/left/input/thumbstick/y";
        right = "/user/hand/right/input/thumbstick/y";
      };
      scroll_horizontal = {
        left = "/user/hand/left/input/thumbstick/x";
        right = "/user/hand/right/input/thumbstick/x";
      };
      show_hide = {
        double_click = true;
        left = "/user/hand/left/input/y/click";
      };
      space_drag.left = "/user/hand/left/input/menu/click";
      space_reset = {
        double_click = true;
        left = "/user/hand/left/input/menu/click";
      };
      click_modifier_right.left = "/user/hand/left/input/trigger/touch";
      move_mouse = {
        left = "/user/hand/left/input/trigger/touch";
        right = "/user/hand/right/input/trigger/touch";
      };
    };
  in {
    environment.systemPackages = [pkgs.vj.vjvr pkgs.android-tools pkgs.scrcpy pkgs.wayvr];
    environment.sessionVariables.VJSHELL_VR = "1";
    environment.etc."vjvr.json".text = builtins.toJSON {
      server_version = config.services.wivrn.package.version;
      inherit apk;
      apk_sha256 = apkHash;
      apk_package = "org.meumeu.wivrn.github";
      hotspot_unit = "create_ap.service";
      hotspot_interface = "ap0";
      hotspot_passphrase = "/var/lib/hotspot/passphrase";
      wifi_interface = "wlp15s0";
      hostname = config.networking.hostName;
      preview_command = lib.getExe pkgs.scrcpy;
      desktop_command = lib.getExe pkgs.wayvr;
    };

    persistence.data.directories = [
      {
        directory = ".android";
        mode = "0700";
      }
      {
        directory = ".local/state/vjvr";
        mode = "0700";
      }
      ".config/wayvr"
    ];
    persistence.cache.directories = [".config/wivrn"];

    hjem.users.${user}.files = {
      ".config/wayvr/openxr_actions.json5".text = builtins.toJSON [
        (touchBindings // {profile = "/interaction_profiles/oculus/touch_controller";})
      ];
      ".config/wayvr/conf.d/zzz-wayland.yaml".text = "xwayland_by_default: false\n";
      ".config/wayvr/conf.d/zzz-gruvbox.yaml".text = "color_palette: gruvbox.json\n";
      ".config/wayvr/palettes/gruvbox.json".text = builtins.toJSON {
        primary = theme.base0E;
        on_primary = theme.base00;
        secondary = theme.base0A;
        on_secondary = theme.base00;
        tertiary = theme.base0C;
        on_tertiary = theme.base00;
        danger = theme.base08;
        on_danger = theme.base00;
        background = theme.base01;
        on_background = theme.base06;
        background_variant = theme.base02;
        on_background_variant = theme.base05;
        background_contrast = theme.base00;
        on_background_contrast = theme.base07;
        outline = theme.base03;
        shadow = theme.base00;
        highlight = theme.base03;
      };
    };

    services.wivrn = {
      package = pkgs.vj.wivrn;
      steam.importOXRRuntimes = true;
      extraServerFlags = ["--no-manage-active-runtime"];
    };

    systemd.user.services.vjvr = {
      wantedBy = ["graphical-session.target"];
      after = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      enableDefaultPath = false;
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.vj.vjvr} serve";
        Restart = "on-failure";
        RestartSec = 2;
        UMask = "0077";
        TimeoutStopSec = 240;
      };
    };

    systemd.user.services.vjvr-desktop = {
      after = ["graphical-session.target" "wivrn.service"];
      partOf = ["graphical-session.target" "wivrn.service"];
      environment.XR_RUNTIME_JSON = "${config.services.wivrn.package}/share/openxr/1/openxr_wivrn.json";
      enableDefaultPath = false;
      serviceConfig = {
        ExecStart = desktop;
        TimeoutStopSec = 5;
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id === "org.freedesktop.systemd1.manage-units" &&
            subject.user === ${builtins.toJSON user} && subject.local && subject.active &&
            action.lookup("unit") === "create_ap.service" &&
            ["start", "stop", "restart"].indexOf(action.lookup("verb")) !== -1) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
