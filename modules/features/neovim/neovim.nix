{
  self,
  wrapperModules,
  ...
}: {
  wrappers._neovim-main = {
    config,
    wlib,
    lib,
    pkgs,
    ...
  }: {
    imports = [wrapperModules._dynamic];

    options = {
      initLua = lib.mkOption {
        type = wlib.types.stringable;
        default = lib.fileset.toSource {
          root = ./.;
          fileset = lib.fileset.difference ./. (lib.fileset.fileFilter (f: f.hasExt "nix") ./.);
        };
      };
      dynamicInitLua = lib.mkOption {
        type = lib.types.either wlib.types.stringable lib.types.luaInline;
        default = lib.generators.mkLuaInline ''
          (function()
            local directory = (vim.env.NIXCONF_ROOT or (vim.uv.os_homedir() .. '/nixconf')) .. '/modules/features/neovim'
            if vim.fn.filereadable(directory .. '/lua/init.lua') == 1 then
              return directory
            end
            return ${lib.generators.toLua {} (toString config.initLua)}
          end)()
        '';
      };
    };
    config = {
      settings.config_directory =
        if config.dynamicMode
        then config.dynamicInitLua
        else toString config.initLua;

      runtimePkgs = [
        pkgs.git
        pkgs.ripgrep
        pkgs.fd
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
    };
  };

  wrappers.neovim = {wlib, ...}: {
    imports = [
      wlib.wrapperModules.neovim
      wrapperModules._neovim-main
      wrapperModules._neovim-lua
      wrapperModules._neovim-nix
    ];
  };

  wrappers.neovimDynamic = {wlib, ...}: {
    imports = [
      wlib.wrapperModules.neovim
      wrapperModules._neovim-main
      wrapperModules._neovim-allServers
    ];
    dynamicMode = true;
  };

  checks = pkgs: {
    neovim-colorscheme = self.lib.mkGeneratedFileCheck {
      inherit pkgs;
      name = "neovim-colorscheme";
      generated = import ./_colorscheme.nix {inherit (self.lib) theme darken;};
      committed = ./lua/colorscheme.lua;
      path = "modules/features/neovim/lua/colorscheme.lua";
    };
  };
}
