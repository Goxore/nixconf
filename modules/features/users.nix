{
  modules.nixos.base = {
    config,
    pkgs,
    ...
  }: let
    passwordFile =
      if config.persistence.enable
      then "/persist/passwd"
      else "/var/lib/secrets/password";
  in {
    users.users.${config.preferences.user.name} = {
      isNormalUser = true;
      description = "${config.preferences.user.name}'s account";
      extraGroups = ["wheel" "networkmanager"];
      shell = pkgs.vj.environment;

      hashedPasswordFile = passwordFile;
    };

    systemd.tmpfiles.rules = ["z ${passwordFile} 0600 root root - -"];
  };
}
