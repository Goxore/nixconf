{
  config,
  pkgs,
  lib,
  inputs,
  outputs,
  system,
  myLib,
  ...
}: {
  imports =
    [
      ./hardware-configuration.nix
      (import ./disko.nix {device = "/dev/nvme1n1";})
      inputs.disko.nixosModules.default
      "${inputs.nixpkgs-wivrn}/nixos/modules/services/video/wivrn.nix"
    ]
    ++ (myLib.filesIn ./included);

  boot = {
    loader.grub.enable = true;
    loader.grub.efiSupport = true;
    loader.grub.efiInstallAsRemovable = true;

    boot.supportedFilesystems.ntfs = true;

    kernelParams = ["quiet" "udev.log_level=3" "nvidia_drm.fbdev=1" "nvidia_drm.modeset=1"];
    kernelModules = ["coretemp" "cpuid" "v4l2loopback"];
  };

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users.enable = true;
    power-management.enable = true;
    sops.enable = false;
    autologin.user = "yurii";

    virtualisation.enable = lib.mkDefaut true;

    hyprland.enable = true;

    home-users = {
      "yurii" = {
        userConfig = ./home.nix;
        userSettings = {
          extraGroups = ["networkmanager" "wheel" "libvirtd" "docker" "adbusers" "openrazer"];
        };
      };
    };

    impermanence.enable = true;
    impermanence.nukeRoot.enable = true;
  };
  users.users.yurii.hashedPasswordFile = "/persist/passwd";

  # programs.hyprland.package = inputs.hyprland.packages."${pkgs.system}".hyprland;
  security.polkit.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;

  virtualisation.libvirtd.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings = {
      dns_enabled = true;
    };
  };

  networking.hostName = "laptop";
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  hardware = {
    enableAllFirmware = true;
    cpu.amd.updateMicrocode = true; #needs unfree
    bluetooth.enable = true;
    opengl = {
      enable = true;
      driSupport32Bit = true;
      driSupport = true;
    };
  };

  hardware.openrazer.enable = true;

  services = {
    hardware.openrgb.enable = true;
    flatpak.enable = true;
    udisks2.enable = true;
    printing.enable = true;
  };

  programs.zsh.enable = true;
  programs.hyprland.enable = true;
  programs.adb.enable = true;

  programs.alvr.enable = true;
  programs.alvr.openFirewall = true;

  programs.dconf.enable = true;

  # services.monado.enable = true;
  # services.monado.highPriority = true;
  # services.monado.defaultRuntime = true;
  #
  # services.avahi.enable = true;
  # services.avahi.publish.userServices = true;

  services.wivrn = {
    package =
      (import inputs.nixpkgs-wivrn {
        system = "${pkgs.system}";
        config = {allowUnfree = true;};
      })
      .wivrn;
    # package = inputs.nixpkgs-wivrn.legacyPackages.${pkgs.system}.wivrn;
    enable = true;
    openFirewall = true;
    defaultRuntime = true;
    highPriority = true;
  };

  environment.systemPackages = with pkgs; [
    wineWowPackages.stable
    wineWowPackages.waylandFull
    winetricks
    (pkgs.writeTextFile {
      name = "configure-gtk";
      destination = "/bin/configure-gtk";
      executable = true;
      text = let
        schema = pkgs.gsettings-desktop-schemas;
        datadir = "${schema}/share/gsettings-schemas/${schema.name}";
      in ''
        gnome_schema=org.gnome.desktop.interface
        gsettings set $gnome_schema gtk-theme 'Dracula'
      '';
    })
    glib
    # inputs.nixpkgs-wivrn.legacyPackages.${pkgs.system}.wivrn
  ];

  system.activationScripts = {
    myCustomConfigFile = ''
      cat << EOF > /home/yurii/.config/myconfigfile
      test = a
      test2 = b
      kek = cheburek
      EOF
    '';
  };

  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
  xdg.portal.enable = true;

  system.stateVersion = "23.11";
}
