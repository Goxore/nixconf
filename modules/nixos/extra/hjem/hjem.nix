{inputs, ...}: {
  flake.nixosModules.extra_hjem = {config, ...}: let
    user = config.preferences.user.name;
  in {
    imports = [
      inputs.hjem.nixosModules.default
    ];

    config = {
      hjem = {
        users."${user}" = {
          enable = true;
          directory = "/home/${user}";
          user = "${user}";
        };

        clobberByDefault = true;
      };
    };
  };
}
