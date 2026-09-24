{
  lib,
  self,
  root,
  ...
}: let
  members = (builtins.fromTOML (builtins.readFile (root + "/Cargo.toml"))).workspace.members;

  crates = lib.listToAttrs (map (member: lib.nameValuePair (baseNameOf member) member) members);

  memberFiles = member:
    builtins.filter builtins.pathExists [
      (root + "/${member}/Cargo.toml")
      (root + "/${member}/src")
      (root + "/${member}/tests")
    ];

  source = lib.fileset.toSource {
    inherit root;
    fileset = lib.fileset.unions ([
        (root + "/Cargo.toml")
        (root + "/Cargo.lock")
      ]
      ++ builtins.concatMap memberFiles members);
  };
in {
  lib.rustShell = pkgs: runtimePkgs:
    pkgs.mkShell {
      packages =
        [
          pkgs.cargo
          pkgs.rustc
          pkgs.clippy
          pkgs.rustfmt
          pkgs.rust-analyzer
        ]
        ++ runtimePkgs;
    };

  lib.rustCrate = pkgs: name: extra:
    pkgs.rustPlatform.buildRustPackage (lib.recursiveUpdate {
        pname = name;
        version = "0.1.0";
        src = source;
        buildAndTestSubdir = crates.${name};
        cargoLock.lockFile = root + "/Cargo.lock";
        meta.mainProgram = name;
      }
      extra);

  checks = pkgs:
    lib.mergeAttrsList (lib.mapAttrsToList (name: member: {
        "${name}-lint" = self.lib.rustCrate pkgs name {
          pname = "${name}-lint";
          nativeBuildInputs = [pkgs.clippy pkgs.rustfmt];
          buildPhase = "cd ${member} && cargo clippy --all-targets -- -D warnings && cargo fmt --check";
          doCheck = false;
          installPhase = "touch $out";
        };

        ${name} =
          pkgs.vj.${
            name
          }
          or (self.lib.rustCrate pkgs name {
            pname = "${name}-tests";
            installPhase = "touch $out";
          });
      })
      crates);
}
