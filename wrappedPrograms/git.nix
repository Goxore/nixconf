{
  flake.wrappers.git = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.git;
    env = {
      GIT_AUTHOR_NAME = "Yurii";
      GIT_AUTHOR_EMAIL = "yurii@goxore.com";
      GIT_COMMITTER_NAME = "Yurii";
      GIT_COMMITTER_EMAIL = "yurii@goxore.com";
    };
  };
}
