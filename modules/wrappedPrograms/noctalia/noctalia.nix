{
  inputs,
  lib,
  ...
}: let
  inherit
    (lib)
    getExe
    getExe'
    ;
  settings = {
    appLauncher = {
      customLaunchPrefix = "";
      customLaunchPrefixEnabled = false;
      enableClipPreview = true;
      enableClipboardHistory = false;
      iconMode = "tabler";
      pinnedExecs = [];
      position = "center";
      showCategories = true;
      sortByMostUsed = true;
      terminalCommand = "kitty -e";
      useApp2Unit = false;
      viewMode = "list";
    };
    audio = {
      cavaFrameRate = 30;
      externalMixer = "pwvucontrol || pavucontrol";
      mprisBlacklist = [];
      preferredPlayer = "";
      visualizerType = "linear";
      volumeOverdrive = false;
      volumeStep = 5;
    };
    bar = {
      capsuleOpacity = 1;
      density = "comfortable";
      exclusive = true;
      floating = false;
      marginHorizontal = 0.25;
      marginVertical = 0.25;
      monitors = [];
      outerCorners = true;
      position = "left";
      showCapsule = true;
      showOutline = false;
      transparent = false;
      widgets = {
        center = [];
        left = [
          {
            colorizeDistroLogo = false;
            colorizeSystemIcon = "tertiary";
            customIconPath = "";
            enableColorization = true;
            icon = "arrow-badge-right-filled";
            id = "ControlCenter";
            useDistroLogo = false;
          }
          {
            characterCount = 2;
            colorizeIcons = false;
            enableScrollWheel = true;
            followFocusedScreen = false;
            hideUnoccupied = false;
            id = "Workspace";
            labelMode = "none";
            showApplications = false;
            showLabelsOnlyWhenOccupied = true;
          }
        ];
        right = [
          {
            hideWhenZero = false;
            id = "NotificationHistory";
            showUnreadBadge = true;
          }
          {
            id = "PowerProfile";
          }
          {
            displayMode = "alwaysHide";
            id = "Volume";
          }
          {
            deviceNativePath = "";
            displayMode = "onhover";
            hideIfNotDetected = true;
            id = "Battery";
            showNoctaliaPerformance = false;
            showPowerProfiles = false;
            warningThreshold = 30;
          }
          {
            displayMode = "alwaysHide";
            id = "Microphone";
          }
          {
            displayMode = "forceOpen";
            id = "KeyboardLayout";
          }
          {
            customFont = "";
            formatHorizontal = "HH:mm ddd, MMM dd";
            formatVertical = "HH mm - dd MM";
            id = "Clock";
            useCustomFont = false;
            usePrimaryColor = true;
          }
          {
            blacklist = [];
            colorizeIcons = false;
            drawerEnabled = true;
            hidePassive = false;
            id = "Tray";
            pinned = [];
          }
        ];
      };
    };
    brightness = {
      brightnessStep = 5;
      enableDdcSupport = false;
      enforceMinimum = true;
    };
    calendar = {
      cards = [
        {
          enabled = true;
          id = "calendar-header-card";
        }
        {
          enabled = true;
          id = "calendar-month-card";
        }
        {
          enabled = true;
          id = "timer-card";
        }
        {
          enabled = true;
          id = "weather-card";
        }
      ];
    };
    colorSchemes = {
      darkMode = true;
      generateTemplatesForPredefined = true;
      manualSunrise = "06:30";
      manualSunset = "18:30";
      matugenSchemeType = "scheme-fruit-salad";
      predefinedScheme = "Gruvbox";
      schedulingMode = "off";
      useWallpaperColors = false;
    };
    controlCenter = {
      cards = [
        {
          enabled = true;
          id = "profile-card";
        }
        {
          enabled = true;
          id = "shortcuts-card";
        }
        {
          enabled = true;
          id = "audio-card";
        }
        {
          enabled = false;
          id = "brightness-card";
        }
        {
          enabled = true;
          id = "weather-card";
        }
        {
          enabled = true;
          id = "media-sysmon-card";
        }
      ];
      position = "close_to_bar_button";
      shortcuts = {
        left = [
          {id = "WiFi";}
          {id = "Bluetooth";}
          {id = "ScreenRecorder";}
        ];
        right = [
          {id = "Notifications";}
          {id = "PowerProfile";}
        ];
      };
    };
    desktopWidgets = {
      enabled = false;
      gridSnap = false;
      monitorWidgets = [
        {
          name = "HDMI-A-1";
          widgets = [
            {
              hideMode = "visible";
              id = "MediaPlayer";
              showBackground = true;
              showButtons = true;
              visualizerType = "linear";
              x = 100;
              y = 200;
            }
          ];
        }
      ];
    };
    dock = {
      animationSpeed = 2;
      backgroundOpacity = 1;
      colorizeIcons = false;
      deadOpacity = 0.6;
      displayMode = "auto_hide";
      enabled = false;
      floatingRatio = 1;
      inactiveIndicators = false;
      monitors = [];
      onlySameOutput = true;
      pinnedApps = [];
      pinnedStatic = false;
      size = 1;
    };
    general = {
      allowPanelsOnScreenWithoutBar = true;
      animationDisabled = false;
      animationSpeed = 1;
      avatarImage = "/home/yurii/.face";
      boxRadiusRatio = 1;
      compactLockScreen = false;
      dimmerOpacity = 0.15;
      enableShadows = true;
      forceBlackScreenCorners = false;
      iRadiusRatio = 1;
      language = "";
      lockOnSuspend = true;
      radiusRatio = 1;
      scaleRatio = 1;
      screenRadiusRatio = 1;
      shadowDirection = "bottom_right";
      shadowOffsetX = 2;
      shadowOffsetY = 3;
      showHibernateOnLockScreen = false;
      showScreenCorners = false;
      showSessionButtonsOnLockScreen = true;
    };
    hooks = {
      darkModeChange = "";
      enabled = false;
      performanceModeDisabled = "";
      performanceModeEnabled = "";
      screenLock = "";
      screenUnlock = "";
      wallpaperChange = "";
    };
    location = {
      analogClockInCalendar = false;
      firstDayOfWeek = -1;
      showCalendarEvents = true;
      showCalendarWeather = true;
      showWeekNumberInCalendar = false;
      use12hourFormat = false;
      useFahrenheit = false;
      weatherEnabled = true;
      weatherShowEffects = true;
    };
    network = {wifiEnabled = true;};
    nightLight = {
      autoSchedule = true;
      dayTemp = "6500";
      enabled = false;
      forced = false;
      manualSunrise = "06:30";
      manualSunset = "18:30";
      nightTemp = "4000";
    };
    notifications = {
      backgroundOpacity = 1;
      criticalUrgencyDuration = 15;
      enableKeyboardLayoutToast = true;
      enabled = true;
      location = "top_right";
      lowUrgencyDuration = 8;
      monitors = [];
      normalUrgencyDuration = 8;
      overlayLayer = true;
      respectExpireTimeout = false;
      sounds = {
        criticalSoundFile = "";
        enabled = false;
        excludedApps = "discord,firefox,chrome,chromium,edge";
        lowSoundFile = "";
        normalSoundFile = "";
        separateSounds = false;
        volume = 0.5;
      };
    };
    osd = {
      autoHideMs = 3000;
      backgroundOpacity = 1;
      enabled = true;
      enabledTypes = [
        0
        1
        2
        4
      ];
      location = "bottom";
      monitors = [];
      overlayLayer = true;
    };
    screenRecorder = {
      audioCodec = "opus";
      audioSource = "default_output";
      colorRange = "limited";
      directory = "/home/yurii/Videos";
      frameRate = 60;
      quality = "very_high";
      showCursor = true;
      videoCodec = "h264";
      videoSource = "portal";
    };
    sessionMenu = {
      countdownDuration = 10000;
      enableCountdown = true;
      largeButtonsStyle = false;
      position = "center";
      powerOptions = [
        {
          action = "lock";
          command = "";
          countdownEnabled = true;
          enabled = true;
        }
        {
          action = "suspend";
          command = "";
          countdownEnabled = true;
          enabled = true;
        }
        {
          action = "hibernate";
          command = "";
          countdownEnabled = true;
          enabled = true;
        }
        {
          action = "reboot";
          command = "";
          countdownEnabled = true;
          enabled = true;
        }
        {
          action = "logout";
          command = "";
          countdownEnabled = true;
          enabled = true;
        }
        {
          action = "shutdown";
          command = "";
          countdownEnabled = true;
          enabled = true;
        }
      ];
      showHeader = true;
    };
    settingsVersion = 32;
    systemMonitor = {
      cpuCriticalThreshold = 90;
      cpuPollingInterval = 3000;
      cpuWarningThreshold = 80;
      criticalColor = "";
      diskCriticalThreshold = 90;
      diskPollingInterval = 3000;
      diskWarningThreshold = 80;
      enableDgpuMonitoring = false;
      gpuCriticalThreshold = 90;
      gpuPollingInterval = 3000;
      gpuWarningThreshold = 80;
      memCriticalThreshold = 90;
      memPollingInterval = 3000;
      memWarningThreshold = 80;
      networkPollingInterval = 3000;
      tempCriticalThreshold = 90;
      tempPollingInterval = 3000;
      tempWarningThreshold = 80;
      useCustomColors = false;
      warningColor = "";
    };
    templates = {
      alacritty = false;
      cava = false;
      code = false;
      discord = false;
      emacs = false;
      enableUserTemplates = false;
      foot = false;
      fuzzel = false;
      ghostty = false;
      gtk = false;
      helix = false;
      hyprland = false;
      kcolorscheme = false;
      kitty = false;
      mango = false;
      niri = false;
      pywalfox = false;
      qt = false;
      spicetify = false;
      telegram = false;
      vicinae = false;
      walker = false;
      wezterm = false;
      yazi = false;
      zed = false;
    };
    ui = {
      bluetoothDetailsViewMode = "grid";
      bluetoothHideUnnamedDevices = false;
      fontDefault = "Sans Serif";
      fontDefaultScale = 1;
      fontFixed = "monospace";
      fontFixedScale = 1;
      panelBackgroundOpacity = 1;
      panelsAttachedToBar = true;
      settingsPanelMode = "attached";
      tooltipsEnabled = true;
      wifiDetailsViewMode = "grid";
    };
    wallpaper = {
      directory = "/home/yurii/Pictures/Wallpapers";
      enableMultiMonitorDirectories = false;
      enabled = false;
      fillColor = "#000000";
      fillMode = "crop";
      hideWallpaperFilenames = false;
      monitorDirectories = [];
      overviewEnabled = false;
      panelPosition = "follow_bar";
      randomEnabled = false;
      randomIntervalSec = 300;
      recursiveSearch = false;
      setWallpaperOnAllMonitors = true;
      transitionDuration = 1500;
      transitionEdgeSmoothness = 0.05;
      transitionType = "random";
      useWallhaven = false;
      wallhavenCategories = "111";
      wallhavenOrder = "desc";
      wallhavenPurity = "100";
      wallhavenQuery = "";
      wallhavenRatios = "";
      wallhavenResolutionHeight = "";
      wallhavenResolutionMode = "atleast";
      wallhavenResolutionWidth = "";
      wallhavenSorting = "relevance";
    };
  };
in {
  perSystem = {pkgs, ...}: let
    noctalia-shell = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.noctalia-shell.overrideAttrs (final: prev: {
        version = "3.8.0";
        src = pkgs.fetchFromGitHub {
          owner = "noctalia-dev";
          repo = "noctalia-shell";
          tag = "v3.8.0";
          hash = "sha256-Bh4XcEyG6XRQugahL/2Vd42k/YeGK0f+yW3+Oc74Rp4=";
        };
      });
      env = {
        "NOCTALIA_SETTINGS_FILE" =
          pkgs.writeText "config.json" (builtins.toJSON settings);
      };
    };
    start-noctalia-shell = pkgs.writeShellApplication {
      name = "start-noctalia-shell";
      text = ''
        ${getExe noctalia-shell} &

        CITY_FILE=/persist/city

        if [ -f "$CITY_FILE" ]; then
          sleep 5
          ${getExe noctalia-shell} ipc call location set "$(cat "$CITY_FILE")"
        else
          ${getExe' pkgs.libnotify "notify-send"} "Noctalia" "File $CITY_FILE does not exist"
        fi
      '';
    };
    dump-noctalia-shell = pkgs.writeShellApplication {
      name = "dump-noctalia-shell";
      text = ''
        ${getExe noctalia-shell} ipc call state all \
        | nix eval --impure --expr 'builtins.fromJSON (builtins.readFile /dev/stdin)'
      '';
    };
  in {
    packages = {
      inherit start-noctalia-shell;
      inherit noctalia-shell;

      noctalia-bundle = pkgs.symlinkJoin {
        name = "noctalia-bundle";
        paths = [
          noctalia-shell
          start-noctalia-shell
          dump-noctalia-shell
        ];
      };
    };
  };
}
