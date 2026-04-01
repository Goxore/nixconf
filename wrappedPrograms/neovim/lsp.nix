{self, ...}: {
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
}
