{
  modules.nixos.personal = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.vj.godot
    ];

    persistence.cache.directories = [".config/godot"];
  };
}
