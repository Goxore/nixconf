{inputs, ...}: {
  nix.registry = {
    n.flake = inputs.nixpkgs;
    u = {
      from = {
        id = "u";
        type = "indirect";
      };
      to = {
        owner = "nixos";
        repo = "nixpkgs";
        ref = "nixos-unstable";
        type = "github";
      };
    };
  };
}
