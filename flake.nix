{
  # ================================================================ #
  # =                           WELCOME!                           = #
  # ================================================================ #

  description = "Yurii's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    xremap-flake.url = "github:xremap/nix-flake";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    prism = {
      url = "github:IogaMaster/prism";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nixpkgs-nvidia-535 = {
        url = "github:nixos/nixpkgs/b604023e0a5549b65da3040a07d2beb29ac9fc63";
    };

    hyprland.url = "github:hyprwm/Hyprland";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };

    persist-retro.url = "github:Geometer1729/persist-retro";

  };

  outputs = {...} @ inputs: let
    # super simple boilerplate-reducing
    # lib with a bunch of functions
    myLib = import ./myLib/default.nix {inherit inputs;};
  in
    with myLib; {
      nixosConfigurations = {
        # ===================== NixOS Configurations ===================== #

        laptop = mkSystem ./hosts/laptop2/configuration.nix;
        work = mkSystem ./hosts/work/configuration.nix;
        vps = mkSystem ./hosts/vps/configuration.nix;
        liveiso = mkSystem ./hosts/liveiso/configuration.nix;

      };

      homeConfigurations = {
        # ================ Maintained home configurations ================ #

        "yurii@laptop" = mkHome "x86_64-linux" ./hosts/laptop/home.nix;
        "yurii@work" = mkHome "x86_64-linux" ./hosts/work/home.nix;

        # ========================= Discontinued ========================= #
        # This one doesn't work. Left it in case I ever want to use it again

        "yurii@osxvm" = mkHome "x86_64-darwin" ./hosts/osxvm/home.nix;
      };

      homeManagerModules.default = ./homeManagerModules;
      nixosModules.default = ./nixosModules;
    };
}
