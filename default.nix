{
  revision ? null,
  lastModified ? null,
}:
import ./lib/frame.nix {
  inputs = (import ./.tack) {};
  root = ./.;
  build = {inherit revision lastModified;};
}
