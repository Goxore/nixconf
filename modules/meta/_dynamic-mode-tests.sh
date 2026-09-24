set -euo pipefail

export QT_QPA_PLATFORM=offscreen
unset QS_NO_RELOAD_POPUP
unset WAYLAND_DISPLAY
export NIXCONF_ROOT="$TMPDIR/check out"
export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$TMPDIR/no-system-bus"

shellLog="$TMPDIR/shell.log"
fixture="$NIXCONF_ROOT/modules/features/vjshell/shell.qml"
editorConfig="$NIXCONF_ROOT/modules/features/neovim/lua/init.lua"

mkdir -p "$(dirname "$fixture")/Commons" "$(dirname "$editorConfig")"
cp "$colors" "$(dirname "$fixture")/Commons/Colors.qml"

poll_until() {
  local label=$1
  shift
  for _ in $(seq 1 100); do
    if "$@"; then return 0; fi
    sleep 0.1
  done
  printf 'timed out waiting for %s\n' "$label"
  cat "$shellLog"
  exit 1
}

serves() {
  test "$("$1" ipc call dynamicTest value 2>/dev/null || true)" = "$2"
}

rejected_the_fixture() {
  grep -q 'Failed to load configuration' "$shellLog"
}

qml_reporting() {
  cat <<QML
import Quickshell
import Quickshell.Io
ShellRoot {
    IpcHandler {
        target: "dynamicTest"
        function value(): string { return "$1"; }
    }
}
QML
}

publish() {
  qml_reporting "$1" > "$fixture"
}

publish_atomically() {
  qml_reporting "$1" > "$fixture.next"
  mv "$fixture.next" "$fixture"
}

publish before
"$dynamicShell" > "$shellLog" 2>&1 &
shellPid=$!
trap 'kill "$shellPid" 2>/dev/null || true' EXIT

poll_until 'the shell to serve the first fixture' serves "$dynamicShell" before
test "$dynamicShell" != "$rebuiltShell"
poll_until 'a rebuilt wrapper to reach the same live shell' serves "$rebuiltShell" before

publish after
poll_until 'a live edit to reach the rebuilt wrapper' serves "$rebuiltShell" after

for revision in $(seq 1 5); do
  publish_atomically "atomic$revision"
  poll_until "atomic save $revision" serves "$dynamicShell" "atomic$revision"
done

publish_atomically atomic5
sleep 0.2
publish restored
poll_until 'an unchanged atomic save to leave the shell live' serves "$dynamicShell" restored

printf 'import Quickshell\nShellRoot {\n' > "$fixture"
poll_until 'the shell to reject a truncated fixture' rejected_the_fixture
poll_until 'the last good fixture to stay loaded' serves "$dynamicShell" restored

publish repaired
poll_until 'a repaired fixture to load' serves "$rebuiltShell" repaired

for value in first second; do
  printf "vim.g.dynamic_fixture = '%s'\n" "$value" > "$editorConfig"
  timeout 15 "$dynamicEditor" --headless "+lua assert(vim.g.dynamic_fixture == '$value'); vim.cmd('qa!')"
done
NIXCONF_ROOT="$TMPDIR/missing" timeout 15 "$dynamicEditor" --headless "+lua assert(vim.g.colors_name == 'gxvjbox'); vim.cmd('qa!')"
timeout 15 "$staticEditor" --headless "+lua assert(vim.g.colors_name == 'gxvjbox'); assert(vim.g.dynamic_fixture == nil); vim.cmd('qa!')"

echo 'PASS live edits, atomic saves, invalid-save recovery, IPC across rebuilds, and editor fallback'
