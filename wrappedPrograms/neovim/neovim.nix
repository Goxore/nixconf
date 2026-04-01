{
  inputs,
  self,
  ...
}: {
  flake.modules.neovim.main = {
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
        data = null;
        before = ["MAIN_INIT"];
        config = "require('init')";
      };

      specs.plugins = {
        data = [
          pkgs.vimPlugins.lz-n
          pkgs.vimPlugins.plenary-nvim
          pkgs.vimPlugins.nvim-lspconfig
          pkgs.vimPlugins.nvim-treesitter.withAllGrammars

          # completion
          pkgs.vimPlugins.nvim-web-devicons
          pkgs.vimPlugins.lspkind-nvim
          pkgs.vimPlugins.colorful-menu-nvim
          pkgs.vimPlugins.blink-cmp

          # misc
          pkgs.vimPlugins.snacks-nvim
          pkgs.vimPlugins.oil-nvim
          pkgs.vimPlugins.lualine-nvim
          pkgs.vimPlugins.luasnip
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

      env.LADSPA_PATH = "${pkgs.deepfilternet}lib/ladspa/libdeep_filter_ladspa.so";
    };
  };

  flake.modules.neovim.lua = {pkgs, ...}: {
    extraPackages = [
      pkgs.lua-language-server
    ];

    specs.lua-language-server = {
      data = [
        pkgs.vimPlugins.nvim-lspconfig
        pkgs.vimPlugins.blink-cmp
      ];
      config = ''vim.lsp.enable("lua_ls")'';
    };
  };

  flake.modules.neovim.ts = {pkgs, ...}: {
    extraPackages = [pkgs.typescript-language-server];
    specs.ts = {
      data = [pkgs.vimPlugins.nvim-lspconfig];
      config =
        #lua
        ''
          vim.lsp.config("ts_ls", {
            settings = {
              suggestionActions = {
                enabled = false
              }
            }
          })
          vim.lsp.enable("ts_ls")
        '';
    };
  };

  flake.modules.neovim.astro = {pkgs, ...}: {
    extraPackages = [pkgs.astro-language-server];

    specs.astro = {
      data = [pkgs.vimPlugins.nvim-lspconfig];
      config =
        #lua
        ''
          vim.lsp.config("astro", {
            init_options = {
              typescript = {
                tsdk = "node_modules/typescript/lib",
              }
            },
          })
          vim.lsp.enable("astro")
        '';
    };
  };

  flake.modules.neovim.qml = {pkgs, ...}: {
    extraPackages = [pkgs.kdePackages.qtdeclarative];

    specs.qml = {
      data = [pkgs.vimPlugins.nvim-lspconfig];
      config =
        #lua
        ''
          vim.lsp.config("qmlls", {
            cmd = { "qmlls", "-E" },
          })
          vim.lsp.enable("qmlls")
        '';
    };
  };

  flake.modules.neovim.rust = {pkgs, ...}: {
    extraPackages = [pkgs.rust-analyzer];

    specs.rust = {
      data = [pkgs.vimPlugins.nvim-lspconfig];
      config =
        #lua
        ''
          vim.lsp.enable("rust_analyzer")
        '';
    };
  };

  flake.modules.neovim.nix = {pkgs, ...}: {
    extraPackages = [
      pkgs.nixd
      pkgs.alejandra
    ];

    specs.nix = {
      data = [pkgs.vimPlugins.nvim-lspconfig];
      config =
        #lua
        ''
          vim.lsp.config("nixd", {
            cmd = { "nixd" },
            settings = {
              nixd = {
                nixpkgs = {
                  expr = "import <nixpkgs> { }",
                },
                formatting = {
                  command = { "alejandra" },
                },
              },
            },
          })
          vim.lsp.enable("nixd")
        '';
    };
  };

  flake.modules.neovim.mdx = {pkgs, ...}: {
    extraPackages = [
      pkgs.mdx-language-server
    ];

    specs.mdx = {
      data = [pkgs.vimPlugins.nvim-lspconfig];
      config =
        #lua
        ''
          vim.filetype.add({
            extension = {
              mdx = "mdx",
            },
          })
          vim.lsp.enable("mdx_analyzer")
        '';
    };
  };

  flake.modules.neovim.gleam = {pkgs, ...}: {
    specs.gleam = {
      data = [pkgs.vimPlugins.nvim-lspconfig];
      config = ''vim.lsp.enable("gleam")'';
    };
  };

  flake.modules.neovim.vjxl = {pkgs, ...}: let
    selfpkgs = self.packages."${pkgs.system}";
  in {
    extraPackages = [
      selfpkgs.vjxl-format
    ];

    specs.vjxl = {
      data = [
        pkgs.vimPlugins.nvim-lspconfig
        (pkgs.vimPlugins.nvim-treesitter.grammarToPlugin selfpkgs. vjxl-grammar)
      ];
      config =
        #lua
        ''
          vim.lsp.config['parser4'] = {
            cmd = { '/home/yurii/Videos/parser4/target/release/parser4', 'lsp' },
            filetypes = { 'vjxl' },
            root_markers = { '.git' },
            root_dir = vim.fn.getcwd(),
          }
          vim.lsp.enable('parser4')
        '';
    };
  };

  flake.modules.neovim.allServers = {
    imports = [
      self.modules.neovim.lua
      self.modules.neovim.ts
      self.modules.neovim.astro
      self.modules.neovim.qml
      self.modules.neovim.rust
      self.modules.neovim.nix
      self.modules.neovim.gleam
      self.modules.neovim.mdx
      self.modules.neovim.vjxl
    ];
  };

  perSystem = {
    pkgs,
    self',
    ...
  }: {
    packages.neovim = inputs.wrapper-modules.wrappers.neovim.wrap {
      inherit pkgs;
      imports = [
        self.modules.neovim.main
        self.modules.neovim.lua
        self.modules.neovim.nix
      ];
    };

    packages.neovimFull = inputs.wrapper-modules.wrappers.neovim.wrap {
      inherit pkgs;
      dynamicMode = true;
      imports = [
        self.modules.neovim.main
        self.modules.neovim.allServers
      ];
    };

    packages.neovimDynamic = inputs.wrapper-modules.wrappers.neovim.wrap {
      inherit pkgs;
      dynamicMode = true;
      imports = [
        self.modules.neovim.main
        self.modules.neovim.allServers
      ];
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
