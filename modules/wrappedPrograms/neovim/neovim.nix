{
  inputs,
  lib,
  self,
  ...
}: {
  flake.nvimWrapper = {
    config,
    wlib,
    lib,
    pkgs,
    ...
  }: let
    selfpkgs = self.packages."${pkgs.system}";
  in {
    imports = [wlib.wrapperModules.neovim];

    options.settings.test_mode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        If true, use impure config instead for fast edits

        Both versions of the package may be installed simultaneously
      '';
    };
    options.settings.wrapped_config = lib.mkOption {
      type = wlib.types.stringable;
      default = ./.;
    };
    options.settings.unwrapped_config = lib.mkOption {
      type = lib.types.either wlib.types.stringable lib.types.luaInline;
      default = lib.generators.mkLuaInline "vim.uv.os_homedir() .. '/nixconf/modules/wrappedPrograms/neovim'";
    };
    config = {
      env.LADSPA_PATH = "${pkgs.deepfilternet}lib/ladspa/libdeep_filter_ladspa.so";
      settings.config_directory =
        if config.settings.test_mode
        then config.settings.unwrapped_config
        else config.settings.wrapped_config;
      settings.dont_link = config.binName != "nvim";
      binName = lib.mkIf config.settings.test_mode (lib.mkDefault "vim");
      settings.aliases = lib.mkIf (config.binName == "nvim") ["vi"];

      specs.initLua = {
        data = null;
        before = ["MAIN_INIT"];
        config = ''
          require('init')
        '';
      };

      extraPackages = [
        pkgs.lua-language-server
        pkgs.astro-language-server
        pkgs.typescript-language-server
        pkgs.rust-analyzer
        pkgs.kdePackages.qtdeclarative
        pkgs.nixd
        pkgs.alejandra
        pkgs.ffmpeg-full
        selfpkgs.vjxl-format
      ];

      specs.start = let
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

      specs.opt = let
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
            ${lib.getExe self'.packages.devMode} "$@"
        else
            # start normal mode
            ${lib.getExe self'.packages.neovim} "$@"
        fi
      '';
    };

    packages.vjxl-grammar = pkgs.tree-sitter.buildGrammar {
      language = "vjxl";
      version = "0.0.1";
      src = ./vjxl-ts;
    };

    packages.vjxl-format = let
      config = pkgs.writeText "topiary-config.ncl" ''
        {
          languages.vjxl = {
            extensions = ["vjxl"],
            grammar.source.path = "${self'.packages.vjxl-grammar}/parser",
          },
        }
      '';
    in
      pkgs.writeShellScriptBin "format-vjxl" ''
        sed -E 's/[[:space:]]+/ /g' \
        | TOPIARY_LANGUAGE_DIR=${./topiary-queries} \
        ${pkgs.topiary}/bin/topiary \
            --config ${config} \
            format \
            --language vjxl \
            --skip-idempotence
      '';
    # todo:
    # pkgs.writeShellScriptBin "format-vjxl" ''
    #   TOPIARY_LANGUAGE_DIR=${./topiary-queries} \
    #   awk '{ gsub(/  +/, " "); print }' | \
    #   ${pkgs.topiary}/bin/topiary --config ${config} format --language vjxl --skip-idempotence | \
    #   awk '{ gsub(/  +/, " "); print }'
    # '';
  };
}
