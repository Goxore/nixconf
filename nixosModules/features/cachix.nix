{
  pkgs,
  lib,
  ...
}: {
  nix = {
    optimise.automatic = true;
    settings.auto-optimise-store = true;
  };
}
