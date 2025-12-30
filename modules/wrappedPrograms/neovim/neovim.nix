{
  inputs,
  lib,
  ...
}: let
  inherit
    (lib)
    getExe
    ;
in {
  perSystem = {
    pkgs,
    self',
    lib,
    ...
  }: {
    packages.neovimDynamic = pkgs.writeShellApplication {
      name = "nvim";
      text = ''
        if [ -d ~/nixconf/modules/wrappedPrograms/neovim/lua ]; then
            # start dev mode
            ${getExe self'.packages.neovim.devMode} "$@"
        else
            # start normal mode
            ${getExe self'.packages.neovim} "$@"
        fi
      '';
    };

    packages.neovim = inputs.mnw.lib.wrap pkgs {
      neovim = pkgs.neovim-unwrapped;

      extraBinPath = [
        pkgs.lua-language-server
        pkgs.typescript-language-server
        pkgs.rust-analyzer
        pkgs.kdePackages.qtdeclarative
        pkgs.nixd
        pkgs.alejandra
      ];

      initLua = ''
        require('init')
        require('lz.n').load('plugins')
      '';

      plugins = let
        p = pkgs.vimPlugins;
        vjxl-grammar = pkgs.tree-sitter.buildGrammar {
          language = "vjxl";
          version = "0.0.1";
          src = ./vjxl-ts;
        };
        tree-sitter-with-vjxl = (
          # sins, idk how else to do it :P
          p.nvim-treesitter.withPlugins (
            p: let
              allPlugins = builtins.attrValues p;
              withMeta =
                builtins.filter
                (plugin: builtins.isAttrs plugin && builtins.hasAttr "meta" plugin)
                allPlugins;
            in
              withMeta ++ [vjxl-grammar]
          )
        );
      in {
        start = [
          p.lz-n
          p.plenary-nvim
          p.nvim-lspconfig
          tree-sitter-with-vjxl

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

        opt = [
          p.lazydev-nvim
          p.gitsigns-nvim
          p.nvim-autopairs
          p.fastaction-nvim
          p.mini-files
          p.codecompanion-nvim
        ];

        dev.myconfig = {
          pure = ./.;
          # impure = "/' .. vim.uv.cwd() .. '/";
          impure = "/' .. vim.uv.os_homedir() .. '/nixconf/modules/wrappedPrograms/neovim";
        };
      };
    };

    packages.neovimDev = self'.packages.neovim.devMode;
  };
}
