{
  lib,
  self,
  ...
}: {
  checks = pkgs: {
    neovim-behavior =
      pkgs.runCommand "neovim-behavior-check" {
        staticEditor = lib.getExe pkgs.vj.neovim;
        dynamicEditor = lib.getExe pkgs.vj.neovimDynamic;
      } ''
        for variant in static dynamic; do
          export NVIM_TEST_ROOT="$TMPDIR/$variant"
          export NIXCONF_ROOT="$TMPDIR/missing"
          ${self.lib.sandboxHome "$NVIM_TEST_ROOT"}
          printf 'first\n' > "$NVIM_TEST_ROOT/undo.txt"
          printf '{"compilerOptions":{"strict":true}}\n' > "$NVIM_TEST_ROOT/tsconfig.json"
          printf '{"name":"nvim-test","private":true}\n' > "$NVIM_TEST_ROOT/package.json"
          printf '{"lockfileVersion":3}\n' > "$NVIM_TEST_ROOT/package-lock.json"
          printf 'const answer:number=1\n' > "$NVIM_TEST_ROOT/main.ts"

          if [ "$variant" = static ]; then
            editor="$staticEditor"
            modes="write undo"
          else
            editor="$dynamicEditor"
            modes="write undo lsp"
          fi
          for mode in $modes; do
            NVIM_TEST_MODE="$mode" timeout 30 "$editor" --headless -i NONE \
              -c "lua vim.schedule(function() local ok, err = pcall(dofile, '${./_neovim-tests.lua}'); if not ok then print(err); vim.cmd('cquit') end end)"
          done
        done
        touch "$out"
      '';
  };
}
