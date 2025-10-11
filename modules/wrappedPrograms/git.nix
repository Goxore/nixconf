{inputs, ...}: {
  perSystem = {pkgs, ...}: let
  in {
    packages.git = inputs.wrappers.lib.makeWrapper {
      inherit pkgs;
      package = pkgs.git;
      env = {
        GIT_AUTHOR_NAME = "Yurii";
        GIT_AUTHOR_EMAIL = "yurii@goxore.com";
      };
    };
  };
}
