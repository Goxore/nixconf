{
  inputs,
  outputs,
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [outputs.homeManagerModules.default];

  programs.git.userName = "yurii";
  programs.git.userEmail = "yurii@goxore.com";

  myHomeManager.impermanence.data.directories = [
    "nixconf"

    "Videos"
    "Documents"
    "Projects"
  ];

  myHomeManager.impermanence.cache.directories = [
    ".local/share/PrismLauncher"
    ".config/openvr"
    ".config/tidal-hifi"

    "Android"
    ".local/share/godot"
    ".config/alvr"
  ];

  programs.foot.enable = true;
  programs.wezterm.enable = true;

  myHomeManager = {
    bundles.general.enable = true;
    bundles.desktop-full.enable = true;

    bundles.gaming.enable = true;

    pipewire.enable = true;
    tenacity.enable = true;

   hyprland.split-workspaces.enable = false;

    monitors = let
      # edp = {
      #   width = 1920;
      #   height = 1080;
      #   refreshRate = 144.;
      #   x = 0;
      #   y = 500;
      #   # x = 760;
      #   # y = 1440;
      # };
    in {
      # "eDP-1" = edp;
      # "eDP-2" = edp;
      "HDMI-A-1" = {
        width = 3440;
        height = 1440;
        refreshRate = 100.;
        # x = 1920;
        # y = 0;
        # x = 0;
        # y = 0;
      };
    };

    workspaces = {
      "2" = {
        monitorId = 0;
        autostart = with pkgs; [
         (lib.getExe firefox)
        ];
      };
      "10" = {
        monitorId = 1;
        autostart =  with pkgs; [
          (lib.getExe telegram-desktop)
          (lib.getExe vesktop)
        ];
      };
    };

    keybinds = {
      "SUPER, Z".package = inputs.woomer.packages.${pkgs.system}.default;
    };

  };

  home = {
    username = "yurii";
    homeDirectory = lib.mkDefault "/home/yurii";
    stateVersion = "22.11";

    packages = with pkgs; [
      obs-studio
      wf-recorder
      prismlauncher
      tidal-hifi
      gnome.gnome-sound-recorder

      opencomposite
    ];
  };

  # xdg.configFile."openxr/1/active_runtime.json".text =
  # ''
  #   {
  #       "file_format_version" : "1.0.0",
  #       "runtime" : 
  #       {
  #           "VALVE_runtime_is_steamvr" : true,
  #           "library_path" : "/home/yurii/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrclient.so",
  #           "name" : "SteamVR"
  #       }
  #   }
  # '';

  # xdg.configFile."openvr/openvrpaths.vrpath".text = ''
  #   {
  #     "config" :
  #     [
  #       "${config.xdg.dataHome}/Steam/config"
  #     ],
  #     "external_drivers": [
  #       "${pkgs.alvr}/lib64/alvr"
  #     ],
  #     "jsonid": "vrpathreg",
  #     "log" :
  #     [
  #       "${config.xdg.dataHome}/Steam/logs"
  #     ],
  #     "runtime" :
  #     [
  #       "${pkgs.opencomposite}/lib/opencomposite"
  #     ],
  #     "version" : 1
  #   }
  # '';

  xdg.configFile."openxr/1/active_runtime.json".source = "${pkgs.wivrn}/share/openxr/1/openxr_wivrn.json";

  xdg.configFile."openvr/openvrpaths.vrpath".text = ''
    {
      "config" :
      [
        "${config.xdg.dataHome}/Steam/config"
      ],
      "external_drivers" : null,
      "jsonid" : "vrpathreg",
      "log" :
      [
        "${config.xdg.dataHome}/Steam/logs"
      ],
      "runtime" :
      [
        "${pkgs.opencomposite}/lib/opencomposite"
      ],
      "version" : 1
    }
  '';
}
