{inputs, ...}: {
  modules.nixos.base = {config, ...}: let
    user = config.preferences.user.name;
  in {
    imports = [
      inputs.hjem.nixosModules.default
    ];

    config = {
      hjem = {
        users.${user} = {
          enable = true;
          directory = "/home/${user}";
          inherit user;
        };

        clobberByDefault = true;
      };
    };
  };
}
