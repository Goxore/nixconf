{ pkgs, inputs, lib, ... }: 

let 
  shell = pkgs.writeShellScriptBin "astalshell" ''
    ${lib.getExe inputs.self.outputs.packages."x86_64-linux".astalshell}
  '';

  astal = inputs.astal.packages.${pkgs.system}.default;
in
{
  myHomeManager = {
    startScripts.astalshell = shell;

    keybinds = {
      # toggle player window
      "$mainMod, M".script = ''
        ${lib.getExe astal} -i lua toggleplayer
      '';
      "$mainMod SHIFT, M".script = ''
        ${lib.getExe astal} -i lua togglelyrics
      '';
    };

  };

  home.packages = [
    shell
  ];
}
