{
  inputs,
  lib,
  self,
  ...
}: let
  inherit
    (lib)
    getExe
    ;
in {
  flake.nvimWrapper = {
    config,
    wlib,
    lib,
    pkgs,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    options.settings.test_mode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        If true, use impure config instead for fast edits

        Both versions of the package may be installed simultaneously
      '';
    };
    config.settings.config_directory =
      if config.settings.test_mode
      then config.settings.unwrapped_config
      else config.settings.wrapped_config;
    options.settings.wrapped_config = lib.mkOption {
      type = wlib.types.stringable;
      default = ./.;
    };
    options.settings.unwrapped_config = lib.mkOption {
      type = lib.types.either wlib.types.stringable lib.types.luaInline;
      default = lib.generators.mkLuaInline "vim.uv.os_homedir() .. '/nixconf/modules/wrappedPrograms/neovim'";
    };
    config.settings.dont_link = config.binName != "nvim";
    config.binName = lib.mkIf config.settings.test_mode (lib.mkDefault "vim");
    config.settings.aliases = lib.mkIf (config.binName == "nvim") ["vi"];

    config.specs.initLua = {
      data = null;
      before = ["MAIN_INIT"];
      config = ''
        require('init')
        require('lz.n').load('plugins')
      '';
    };

    config.extraPackages = [
      pkgs.lua-language-server
      pkgs.typescript-language-server
      pkgs.rust-analyzer
      pkgs.kdePackages.qtdeclarative
      pkgs.nixd
      pkgs.alejandra
    ];

    config.specs.start = let
      p = pkgs.vimPlugins;
      vjxl-grammar = pkgs.tree-sitter.buildGrammar {
        language = "vjxl";
        version = "0.0.1";
        src = ./vjxl-ts;
      };
    in [
      p.lz-n
      p.plenary-nvim
      p.nvim-lspconfig
      p.nvim-treesitter.withAllGrammars
      (p.nvim-treesitter.grammarToPlugin vjxl-grammar)

      # completion
      p.nvim-web-devicons
      p.lspkind-nvim
      p.colorful-menu-nvim
      p.blink-cmp

      # misc
      p.snacks-nvim
      p.oil-nvim
      p.lualine-nvim
      p.luasnip
    ];

    config.specs.opt = let
      p = pkgs.vimPlugins;
    in {
      lazy = true;
      data = [
        p.lazydev-nvim
        p.gitsigns-nvim
        p.nvim-autopairs
        p.fastaction-nvim
        p.mini-files
        p.codecompanion-nvim
      ];
    };
  };

  perSystem = {
    pkgs,
    self',
    ...
  }: {
    packages.neovim = inputs.wrapper-modules.wrappers.neovim.wrap {
      inherit pkgs;
      imports = [self.nvimWrapper];
    };

    packages.devMode = inputs.wrapper-modules.wrappers.neovim.wrap {
      inherit pkgs;
      settings.test_mode = true;
      imports = [self.nvimWrapper];
    };

    packages.neovimDynamic = pkgs.writeShellApplication {
      name = "nvim";
      text = ''
        if [ -d ~/nixconf/modules/wrappedPrograms/neovim/lua ]; then
            # start dev mode
            ${getExe self'.packages.devMode} "$@"
        else
            # start normal mode
            ${getExe self'.packages.neovim} "$@"
        fi
      '';
    };
  };
}
