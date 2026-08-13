{self, ...}: {
  flake.wrappers.neovim-godot = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    specs.lua-language-server = {
      data = [
        pkgs.vimPlugins.nvim-lspconfig
      ];
      config = ''vim.lsp.enable('gdscript')'';
    };
  };

  flake.wrappers.neovim-csharp = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    extraPackages = [
      pkgs.omnisharp-roslyn
    ];

    specs.lua-language-server = {
      data = [
        pkgs.vimPlugins.nvim-lspconfig
      ];
      # config = ''vim.lsp.enable("csharp_ls")'';
      config = ''vim.lsp.enable("omnisharp")'';
    };
  };

  flake.wrappers.neovim-lua = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

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

  flake.wrappers.neovim-ts = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    extraPackages = [
      pkgs.typescript-language-server
      pkgs.typescript
    ];
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

  flake.wrappers.neovim-astro = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    extraPackages = [
      pkgs.astro-language-server
      pkgs.typescript-language-server
      pkgs.typescript
    ];

    specs.astro = {
      data = [pkgs.vimPlugins.nvim-lspconfig];
      config =
        #lua
        ''
          vim.lsp.config("astro", {
            init_options = {
              typescript = {
                tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib",
              },
            },
          })
          vim.lsp.enable("astro")
        '';
    };
  };

  flake.wrappers.neovim-qml = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

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

  flake.wrappers.neovim-rust = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

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

  flake.wrappers.neovim-nix = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

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

  flake.wrappers.neovim-mdx = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

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

  flake.wrappers.neovim-gleam = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    specs.gleam = {
      data = [pkgs.vimPlugins.nvim-lspconfig];
      config = ''vim.lsp.enable("gleam")'';
    };
  };

  flake.wrappers.neovim-vjxl = {
    pkgs,
    config,
    wlib,
    ...
  }: let
    selfpkgs = self.packages."${config.pkgs.stdenv.hostPlatform.system}";
  in {
    imports = [wlib.wrapperModules.neovim];

    extraPackages = [
      selfpkgs.vjxl-format
    ];

    specs.vjxl = {
      data = [
        pkgs.vimPlugins.nvim-lspconfig
        (pkgs.vimPlugins.nvim-treesitter.grammarToPlugin selfpkgs.vjxl-grammar)
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

  flake.wrappers.neovim-custom = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    specs.vjxl = {
      data = [
        pkgs.vimPlugins.nvim-lspconfig
      ];
      config =
        #lua
        ''
          vim.lsp.config['vjcustom'] = {
            -- cmd = { '/home/yurii/Projects/rust/nix-lsp/target/debug/nix-lsp' },
            cmd = { 'nix', 'run', '/home/yurii/Projects/rust/nix-lsp/' },
            filetypes = { 'nix' },
            root_markers = { '.git' },
            root_dir = vim.fn.getcwd(),
          }
          vim.lsp.enable('vjcustom')
        '';
    };
  };

  flake.wrappers.neovim-allServers = {
    imports = [
      self.wrapperModules.neovim-lua
      self.wrapperModules.neovim-ts
      self.wrapperModules.neovim-astro
      self.wrapperModules.neovim-qml
      self.wrapperModules.neovim-rust
      self.wrapperModules.neovim-nix
      self.wrapperModules.neovim-gleam
      self.wrapperModules.neovim-mdx
      self.wrapperModules.neovim-vjxl
      self.wrapperModules.neovim-custom
      self.wrapperModules.neovim-csharp
      self.wrapperModules.neovim-godot
    ];
  };
}
