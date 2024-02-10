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
      (import ./disko.nix { device = "/dev/nvme1n1"; })
      inputs.disko.nixosModules.default
      inputs.impermanence.nixosModules.impermanence
    ]
    ++ (myLib.filesIn ./included);

  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir /btrfs_tmp
    mount /dev/btrfs_vg/root /btrfs_tmp
    if [[ -e /btrfs_tmp/root ]]; then
        mkdir -p /btrfs_tmp/old_roots
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
        mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
    fi

    delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/btrfs_tmp/$i"
        done
        btrfs subvolume delete "$1"
    }

    for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
        delete_subvolume_recursively "$i"
    done

    btrfs subvolume create /btrfs_tmp/root
    umount /btrfs_tmp
  '';

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.home-manager.enable = true;
    power-management.enable = true;
    sops.enable = false;

    virtualisation.enable = lib.mkDefaut true;

    sharedSettings.hyprland.enable = true;
    userName = "yurii";
    userConfig = ./home.nix;
    userNixosSettings = {
      extraGroups = ["networkmanager" "wheel" "libvirtd" "docker" "adbusers" "openrazer"];
    };
  };

  programs.hyprland.package = inputs.hyprland.packages."${pkgs.system}".hyprland;

  security.polkit.enable = true;

  virtualisation.podman = {
    enable = true;

    # Create a `docker` alias for podman, to use it as a drop-in replacement
    dockerCompat = true;

    # Required for containers under podman-compose to be able to talk to each other.
    # defaultNetwork.dnsname.enable = true;
    # For Nixos version > 22.11
    defaultNetwork.settings = {
      dns_enabled = true;
    };
  };
  virtualisation.libvirtd.enable = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

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

  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
  xdg.portal.enable = true;

  services.xserver = {
    enable = true;
    videoDrivers = ["modesetting" "nvidia"];
    layout = "us";
    xkbVariant = "";
    libinput.enable = true;

    displayManager = {
      defaultSession = "hyprland";
    };
  };

  # Services
  services = {
    hardware.openrgb.enable = true;
    flatpak.enable = true;
    udisks2.enable = true;
    printing.enable = true;
  };

  # # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.yurii = {
  #   isNormalUser = true;
  #   description = "yurii";
  #   shell = pkgs.zsh;
  #   extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" "adbusers" "openrazer" ];
  # };

  programs.noisetorch.enable = true;
  programs.kdeconnect.enable = true;
  programs.zsh.enable = true;
  programs.hyprland.enable = true;
  programs.adb.enable = true;

  environment.systemPackages = with pkgs; [
    wineWowPackages.stable
    wineWowPackages.waylandFull
    winetricks
  ];

  # Use the systemd-boot EFI boot loader.
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;

  fileSystems."/persist".neededForBoot = true;
  programs.fuse.userAllowOther = true;
  environment.persistence."/persist/system" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
      { directory = "/var/lib/colord"; user = "colord"; group = "colord"; mode = "u=rwx,g=rx,o="; }
    ];
    files = [
      "/etc/machine-id"
      { file = "/var/keys/secret_file"; parentDirectory = { mode = "u=rwx,g=,o="; }; }
    ];
  };


  system.stateVersion = "23.11"; # Did you read the comment?

}

