{
  self,
  ...
}: {
  flake.wrappers.neovim-main = {
    config,
    wlib,
    lib,
    pkgs,
    ...
  }: {
    options = {
      dynamicMode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          If true, use impure config instead for fast edits

          Both versions of the package may be installed simultaneously
        '';
      };
      initLua = lib.mkOption {
        type = wlib.types.stringable;
        default = ./.;
      };
      dynamicInitLua = lib.mkOption {
        type = lib.types.either wlib.types.stringable lib.types.luaInline;
        default = lib.generators.mkLuaInline "vim.uv.os_homedir() .. '/nixconf/wrappedPrograms/neovim'";
      };
    };
    config = {
      settings.config_directory =
        if config.dynamicMode
        then config.dynamicInitLua
        else config.initLua;

      extraPackages = [
        pkgs.ffmpeg-full
        pkgs.wl-clipboard
      ];

      specs.init = {
        before = ["MAIN_INIT"];
        config = "require('init')";
        data = null;
      };

      specs.plugins = {
        after = ["init"];
        before = ["MAIN_INIT"];
        data = [
          pkgs.vimPlugins.lz-n
          pkgs.vimPlugins.plenary-nvim
          pkgs.vimPlugins.nvim-lspconfig
          pkgs.vimPlugins.nvim-treesitter.withAllGrammars

          pkgs.vimPlugins.nvim-web-devicons
          pkgs.vimPlugins.lspkind-nvim
          pkgs.vimPlugins.colorful-menu-nvim
          pkgs.vimPlugins.blink-cmp

          pkgs.vimPlugins.snacks-nvim
          pkgs.vimPlugins.oil-nvim
          pkgs.vimPlugins.lualine-nvim
          pkgs.vimPlugins.luasnip

          pkgs.vimPlugins.codediff-nvim
        ];
      };

      specs.lazyPlugins = {
        lazy = true;
        data = [
          pkgs.vimPlugins.lazydev-nvim
          pkgs.vimPlugins.gitsigns-nvim
          pkgs.vimPlugins.nvim-autopairs
          pkgs.vimPlugins.fastaction-nvim
          pkgs.vimPlugins.mini-files
          pkgs.vimPlugins.codecompanion-nvim
        ];
      };

      env.LADSPA_PATH = "${pkgs.deepfilternet}/lib/ladspa/libdeep_filter_ladspa.so";
    };
  };

  flake.wrappers.neovim = { wlib, ... }: {
    imports = [
      wlib.wrapperModules.neovim
      self.wrapperModules.neovim-main
      self.wrapperModules.neovim-lua
      self.wrapperModules.neovim-nix
    ];
  };

  flake.wrappers.neovimFull = { wlib, ... }: {
    imports = [
      wlib.wrapperModules.neovim
      self.wrapperModules.neovim-main
      self.wrapperModules.neovim-allServers
    ];
    dynamicMode = true;
  };

  flake.wrappers.neovimDynamic = { wlib, ... }: {
    imports = [
      wlib.wrapperModules.neovim
      self.wrapperModules.neovim-main
      self.wrapperModules.neovim-allServers
    ];
    dynamicMode = true;
  };

  perSystem = {
    pkgs,
    self',
    ...
  }: {
    checks.neovim-colorscheme =
      pkgs.runCommand "neovim-colorscheme-check" {
        generated = import ./_colorscheme.nix {inherit (self) theme darken;};
        passAsFile = ["generated"];
      } ''
        if ! diff -u "$generatedPath" ${./lua/colorscheme.lua}; then
          echo
          echo "wrappedPrograms/neovim/lua/colorscheme.lua is out of sync with theme.nix."
          echo "Regenerate it with:"
          echo "  nix eval --raw .#checks.${pkgs.stdenv.hostPlatform.system}.neovim-colorscheme.generated \\"
          echo "    > wrappedPrograms/neovim/lua/colorscheme.lua"
          exit 1
        fi
        touch $out
      '';

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
  };
}
