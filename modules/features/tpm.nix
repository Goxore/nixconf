{
  modules.nixos.base = {config, ...}: {
    security.tpm2.enable = true;
    users.users.${config.preferences.user.name}.extraGroups = ["tss"];
  };
}
