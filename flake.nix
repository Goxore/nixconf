{
  # ================================================================ #
  # =                           WELCOME!                           = #
  # ================================================================ #

  description = "Yurii's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-gruvboxicons.url = "github:nixos/nixpkgs/21808d22b1cda1898b71cf1a1beb524a97add2c4";
    nixpkgs-neovim.url = "github:nixos/nixpkgs/2b876ec04bb832b10a0bcaa1584da251cafdf884";

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

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };

    stylix.url = "github:danth/stylix/ed91a20c84a80a525780dcb5ea3387dddf6cd2de";

    ags.url = "github:Aylur/ags/v1";

    persist-retro.url = "github:Geometer1729/persist-retro";

    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nix-minecraft.inputs.nixpkgs.follows = "nixpkgs";

    astal = {
      url = "github:aylur/astal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    with (import ./myLib inputs); {
      nixosConfigurations = {
        # ===================== NixOS Configurations ===================== #

        laptop = mkSystem ./hosts/laptop/configuration.nix;
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

        # "yurii@osxvm" = mkHome "x86_64-darwin" ./hosts/osxvm/home.nix;
      };

      homeManagerModules.default = ./homeManagerModules;
      nixosModules.default = ./nixosModules;

      packages."x86_64-linux".astalshell = import ./packages/astalshell {
        inherit (inputs) nixpkgs;
        inherit (inputs) astal;
        system = "x86_64-linux";
      };

      packages."x86_64-linux".neovim =
        (pkgsFor "x86_64-linux").callPackage ./packages/neovim.nix {};
    };
}
