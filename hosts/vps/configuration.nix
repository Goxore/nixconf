{
  pkgs,
  inputs,
  outputs,
  ...
}: {
  imports = [
    outputs.nixosModules.default

    ./hardware-configuration.nix
  ];

  myNixOS.bundles.home-manager.enable = true;
  myNixOS.services.satisfactory.enable = true;

  myNixOS.userName = "main";
  myNixOS.userConfig = ./home.nix;
  myNixOS.userNixosSettings = {
    openssh.authorizedKeys.keys = let
      fv-key = ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItqEoKr3i5VL10cIeueRJutb14BsbqTeDJaNZFndG6W'';
      br-key = ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMMPDyQiSPiKj1ot9m+0mF72ROq4/eHnDbbdSj83SUTw'';
      gx-key = ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII5gM7ApSQ5zuFUoobfx5v2wkozi7rSlcYBEmyUigdk6'';
    in [
      gx-key
      fv-key
      br-key
    ];
    extraGroups = ["wheel" "docker"];
  };

  boot.cleanTmpDir = true;
  zramSwap.enable = true;
  networking.hostName = "vmi1464355";
  networking.domain = "contaboserver.net";

  services.openssh.enable = true;
  services.openssh.passwordAuthentication = false;
  users.users.root.openssh.authorizedKeys.keys = [
    ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII5gM7ApSQ5zuFUoobfx5v2wkozi7rSlcYBEmyUigdk6''
  ];

  virtualisation.docker.enable = true;
  networking.firewall.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    wget
    git
    jdk17
    home-manager
    btop
    du-dust
    lf
    eza
    steamcmd
    steam-run
  ];
}
