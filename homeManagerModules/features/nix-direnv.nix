{
  pkgs,
  lib,
  ...
}: {
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;

    stdlib = ''
      export extra_dev_shell="direnv"
    '';
  };

  myHomeManager.impermanence.directories = [
    ".local/share/direnv/allow"
  ];
}
