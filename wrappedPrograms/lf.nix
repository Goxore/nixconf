{
  inputs,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: let
    previewer = pkgs.writeShellScriptBin "pv.sh" ''
      file=$1
      w=$2
      h=$3
      x=$4
      y=$5

      if [[ "$( ${pkgs.file}/bin/file -Lb --mime-type "$file")" =~ ^image ]]; then
          ${pkgs.kitty}/bin/kitty +kitten icat --silent --stdin no --transfer-mode file --place "''${w}x''${h}@''${x}x''${y}" "$file" < /dev/null > /dev/tty
          exit 1
      fi

          ${pkgs.pistol}/bin/pistol "$file"
    '';
    cleaner = pkgs.writeShellScriptBin "clean.sh" ''
      ${pkgs.kitty}/bin/kitty +kitten icat --clear --stdin no --silent --transfer-mode file < /dev/null > /dev/tty
    '';

    conf =
      pkgs.writeText "config"
      # bash
      ''
        set reverse true
        set preview true
        set hidden true
        set drawbox true
        set icons true
        set ignorecase true
        set cleaner ${cleaner}/bin/clean.sh
        set previewer ${previewer}/bin/pv.sh

        cmd stripspace %stripspace "$f"

        map "\""
        map o
        map d
        map e
        map f
        map . set hidden!
        map D delete
        map p paste
        map dd cut
        map y copy
        map ` mark-load
        map \' mark-load
        map <enter> open
        map a rename
        map r reload
        map C clear
        map U unselect

        map do drag-out

        map g~ cd
        map gh cd
        map g/ /
        map gd cd ~/Downloads
        map gt cd /tmp
        map gv cd ~/Videos
        map go cd ~/Documents
        map gc cd ~/.config
        map gn cd ~/nixconf
        map gp cd ~/Projects
        map gs cd ~/.local/share
        map gm cd /run/media
        map gH cd /persist/users/$HOME

        map eE $ $EDITOR "$f"
        map ee $ ${lib.getExe pkgs.direnv} exec . $EDITOR "$f"
        map e. $ ${lib.getExe pkgs.direnv} exec . $EDITOR .
        map V $ ${lib.getExe pkgs.bat} --paging=always --theme=gruvbox "$f"
        map do $ ${lib.getExe pkgs.ripdrag} -a -x "$fx"

        map <C-d> 5j
        map <C-u> 5k

        setlocal ~/Projects sortby time
        setlocal ~/Projects/* sortby time
        setlocal ~/Downloads/ sortby time
      '';
  in {
    packages.lf = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.lf;
      flags = {
        "-config" = "${conf}";
      };
    };
  };
}
