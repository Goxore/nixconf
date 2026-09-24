{wrapperModules, ...}: {
  wrappers._neovim-godot = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    specs.godot = {
      data = [
        pkgs.vimPlugins.nvim-lspconfig
      ];
      config = ''vim.lsp.enable('gdscript')'';
    };
  };

  wrappers._neovim-csharp = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    runtimePkgs = [
      pkgs.omnisharp-roslyn
    ];

    specs.csharp = {
      data = [
        pkgs.vimPlugins.nvim-lspconfig
      ];
      config = ''vim.lsp.enable("omnisharp")'';
    };
  };

  wrappers._neovim-lua = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    runtimePkgs = [
      pkgs.lua-language-server
    ];

    specs.lua = {
      data = [
        pkgs.vimPlugins.nvim-lspconfig
        pkgs.vimPlugins.blink-cmp
      ];
      config = ''vim.lsp.enable("lua_ls")'';
    };
  };

  wrappers._neovim-ts = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    runtimePkgs = [
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

  wrappers._neovim-astro = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    runtimePkgs = [
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

  wrappers._neovim-qml = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    runtimePkgs = [pkgs.kdePackages.qtdeclarative];

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

  wrappers._neovim-rust = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    runtimePkgs = [pkgs.rust-analyzer];

    specs.rust = {
      data = [pkgs.vimPlugins.nvim-lspconfig];
      config =
        #lua
        ''
          vim.lsp.enable("rust_analyzer")
        '';
    };
  };

  wrappers._neovim-nix = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    runtimePkgs = [
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

  wrappers._neovim-mdx = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    runtimePkgs = [
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

  wrappers._neovim-gleam = {
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.neovim];

    runtimePkgs = [pkgs.gleam];

    specs.gleam = {
      data = [pkgs.vimPlugins.nvim-lspconfig];
      config = ''vim.lsp.enable("gleam")'';
    };
  };

  wrappers._neovim-allServers = {
    imports = [
      wrapperModules._neovim-lua
      wrapperModules._neovim-ts
      wrapperModules._neovim-astro
      wrapperModules._neovim-qml
      wrapperModules._neovim-rust
      wrapperModules._neovim-nix
      wrapperModules._neovim-gleam
      wrapperModules._neovim-mdx
      wrapperModules._neovim-csharp
      wrapperModules._neovim-godot
    ];
  };
}
