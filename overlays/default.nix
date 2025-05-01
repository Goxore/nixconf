{
  inputs,
  outputs,
}: [
  (final: prev: {
    nvimWithDeps = prev.callPackage ../packages/neovim.nix {
      neovim = inputs.nixpkgs-neovim.legacyPackages.${prev.system}.neovim;
    };
  })
]
