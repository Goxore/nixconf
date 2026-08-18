{self, ...}: {
  flake.nixosModules.virt = {
    pkgs,
    config,
    ...
  }: let
    test = self.fun pkgs {
      name = "testus11";
      text = "ls";
    };

    createVm = self.fun pkgs {
      name = "create-vm";
      runtimeInputs = [
        pkgs.libvirt
        pkgs.curl
      ];
      text =
        #bash
        ''
          set -euo pipefail

          NAME="MyVM"
          ISO_DIR="$HOME/Documents/VMISO"
          GRAPHICAL_URL="https://channels.nixos.org/nixos-25.11/latest-nixos-graphical-x86_64-linux.iso"
          MINIMAL_URL="https://channels.nixos.org/nixos-25.11/latest-nixos-minimal-x86_64-linux.iso"

          # MODE="graphical"
          # MODE="minimal"

          case "$MODE" in
            graphical)
              ISO_URL="$GRAPHICAL_URL"
              ISO_FILE="nixos-graphical.iso"
              GRAPHICS_ARGS=(--graphics spice)
              CONSOLE_ARGS=()
              ;;
            minimal)
              ISO_URL="$MINIMAL_URL"
              ISO_FILE="nixos-minimal.iso"
              GRAPHICS_ARGS=(--nographics)
              CONSOLE_ARGS=(--console pty,target_type=virtio)
              ;;
            *)
              exit 1
              ;;
          esac

          ISO_PATH="$ISO_DIR/$ISO_FILE"
          mkdir -p "$ISO_DIR"

          if [ ! -f "$ISO_PATH" ]; then
            curl -L "$ISO_URL" -o "$ISO_PATH"
          fi

          virsh --connect qemu:///system net-start default >/dev/null 2>&1 || true
          virsh --connect qemu:///system net-autostart default >/dev/null 2>&1 || true

          virt-install --name "$NAME" \
            --connect qemu:///system \
            --memory 8196 \
            --vcpus 4 \
            --disk pool=default,size=30 \
            --cdrom "$ISO_PATH" \
            --os-type generic \
            --boot uefi \
            --network network=default \
            "''${GRAPHICS_ARGS[@]}" \
            "''${CONSOLE_ARGS[@]}"
        '';
    };
  in {
    users.users.${config.preferences.user.name}.extraGroups = ["libvirtd"];

    virtualisation = {
      libvirtd.enable = true;
      spiceUSBRedirection.enable = true;
    };

    programs.virt-manager.enable = true;

    environment.systemPackages = [
      pkgs.virt-manager
      pkgs.virt-viewer
      pkgs.spice
      pkgs.spice-gtk
      pkgs.spice-protocol
      createVm
      test
    ];

    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings = {
        dns_enabled = true;
      };
    };

    persistance.directories = [
      "/var/lib/libvirt"
    ];
  };

  flake.fun = pkgs: {
    name,
    text,
    runtimeInputs ? [],
    neovim ? pkgs.neovim,
    shellcheck ? pkgs.shellcheck,
    bashInteractive ? pkgs.bashInteractive,
    extraShellcheckFlags ? [],
  }: let
    inherit (pkgs) lib;

    runtimePath = lib.makeBinPath runtimeInputs;
    scFlags = lib.concatStringsSep " " (["--shell=bash"] ++ extraShellcheckFlags);

    script = ''
      #!${bashInteractive}/bin/bash
      set -euo pipefail

      export PATH="${runtimePath}:$PATH"

      tmpdir="$(mktemp -d)"
      script_path="$tmpdir/${name}.sh"
      trap 'rm -rf "$tmpdir"' EXIT

      cat > "$script_path" << 'EOF'
      ${text}
      EOF

      chmod +x "$script_path"

      run() {
        exec ${bashInteractive}/bin/bash "$script_path" "$@"
      }

      prompt() {
        ${pkgs.bat}/bin/bat --style=plain "$script_path"
        printf "Choice [e=edit, r=run, a=abort]: "
        read -r mode </dev/tty
        case "$mode" in
          r|R) run "$@" ;;
          a|A) exit 1 ;;
        esac
      }

      prompt "$@"

      while true; do
        before="$(stat -c %Y "$script_path")"
        ${neovim}/bin/nvim "$script_path"
        after="$(stat -c %Y "$script_path")"

        if [ "$before" = "$after" ]; then
          prompt "$@"
          continue
        fi

        if ${shellcheck}/bin/shellcheck ${scFlags} "$script_path"; then
          break
        fi

        printf "shellcheck reported issues. [e=re-edit, f=force run, a=abort]: "
        read -r choice </dev/tty
        case "$choice" in
          f|F) break ;;
          a|A) exit 1 ;;
        esac
      done

      run "$@"
    '';
  in
    pkgs.writeTextFile {
      inherit name;
      destination = "/bin/${name}";
      executable = true;
      text = script;
      checkPhase = ''
        ${shellcheck}/bin/shellcheck ${scFlags} "$target" || true
      '';
    };
}
