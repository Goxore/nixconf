use crate::emit::{Shell, quote};
use std::path::Path;

pub fn fish(exe: &Path) -> String {
    let exe = quote(&exe.to_string_lossy(), Shell::Fish);

    format!(
        r#"function __vjenv_pick_shell
    set -l shells ({exe} shells 2>/dev/null)
    test (count $shells) -gt 1; or return 0
    echo "  which devShell?" >&2
    for i in (seq (count $shells))
        echo "    $i) $shells[$i]" >&2
    end
    read -l -P "  choice [1]: " pick
    if string match -qr '^[0-9]+$' -- $pick
        and test $pick -ge 1 -a $pick -le (count $shells)
        echo $shells[$pick]
    else
        echo $shells[1]
    end
end

function __vjenv_ask
    set -q __vjenv_env_pending; or return 0
    set -l dir $__vjenv_env_pending
    set -l token $__vjenv_env_token
    set -e __vjenv_env_pending
    set -e __vjenv_env_token

    status is-interactive; or return 0
    test "$token" != "$__vjenv_env_asked"; or return 0
    set -g __vjenv_env_asked $token

    echo "vjenv: dev environment found in $dir"
    read -l -P "  activate? [y]es / [enter] not now / [n]ever: " ans
    switch $ans
        case y yes
            {exe} allow (__vjenv_pick_shell) >/dev/null
            and __vjenv_refresh
        case n never
            {exe} deny >/dev/null
    end
end

function __vjenv_refresh --on-variable PWD
    {exe} env fish | source
    __vjenv_ask
end

function __vjenv_refresh_prompt --on-event fish_prompt
    __vjenv_refresh
end

function vjenv --wraps={exe}
    if test "$argv[1]" = use
        set -l out ({exe} use --shell fish $argv[2..]); or return 1
        echo $out | source
    else
        {exe} $argv; or return 1
    end
    __vjenv_refresh
end

__vjenv_refresh
"#
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn init() -> String {
        fish(&PathBuf::from("/nix/store/abc-vjenv/bin/vjenv"))
    }

    #[test]
    fn defines_the_functions_it_calls() {
        let text = init();
        for f in [
            "__vjenv_pick_shell",
            "__vjenv_ask",
            "__vjenv_refresh",
            "__vjenv_refresh_prompt",
        ] {
            assert!(text.contains(&format!("function {f}")), "missing {f}");
        }
    }

    #[test]
    fn hooks_both_the_directory_change_and_the_prompt() {
        let text = init();
        assert!(text.contains("--on-variable PWD"));
        assert!(
            text.contains("--on-event fish_prompt"),
            "a change made in place must be noticed without a cd"
        );
        assert!(text.trim_end().ends_with("__vjenv_refresh"));
    }

    #[test]
    fn the_shell_no_longer_edits_the_search_path_itself() {
        let text = init();
        assert!(
            !text.contains("set -gx PATH"),
            "PATH belongs to the binary now, so it cannot drift out of sync"
        );
        assert!(!text.contains("string match -v"));
    }

    #[test]
    fn a_repeated_offer_for_the_same_state_is_only_made_once() {
        let text = init();
        assert!(text.contains("__vjenv_env_asked"));
        assert!(
            text.contains(r#"test "$token" != "$__vjenv_env_asked""#),
            "the guard must key on the token so a changed project asks again"
        );
    }

    #[test]
    fn use_is_told_which_shell_to_emit_for() {
        assert!(init().contains("use --shell fish"));
    }

    #[test]
    fn a_path_needing_quoting_cannot_break_out() {
        let text = fish(&PathBuf::from("/tmp/it's here/vjenv"));
        assert!(text.contains(r"'/tmp/it\'s here/vjenv'"));
    }
}
