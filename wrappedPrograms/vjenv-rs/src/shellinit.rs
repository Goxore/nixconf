use crate::emit::{quote, Shell};
use std::path::Path;

pub const GATED_DIR_VAR: &str = "VJENV_GATED_DIR";

pub fn fish(exe: &Path, gated: Option<&str>) -> String {
    let exe = quote(&exe.to_string_lossy(), Shell::Fish);

    let gate = match gated {
        Some(dir) => {
            let dir = quote(dir, Shell::Fish);
            format!(
                "    set -gx PATH (string match -v -- {dir} $PATH)\n    \
                 set -q VJENV_IDENTITY; and set -gx PATH {dir} $PATH\n"
            )
        }
        None => String::new(),
    };

    format!(
        r#"function __vjenv_env_set -a name value
    set -a __vjenv_env_names $name
    if set -q $name
        set -a __vjenv_env_olds "$$name"
    else
        set -a __vjenv_env_olds \x01
    end
    set -gx $name $value
end

function __vjenv_env_path
    set -l new
    for p in $argv $__vjenv_env_oldpath
        contains -- $p $new; or set -a new $p
    end
    set -gx PATH $new
end

function __vjenv_env_unload
    if set -q __vjenv_env_names
        for i in (seq (count $__vjenv_env_names))
            if test "$__vjenv_env_olds[$i]" = \x01
                set -e $__vjenv_env_names[$i]
            else
                set -gx $__vjenv_env_names[$i] $__vjenv_env_olds[$i]
            end
        end
    end
    set -q __vjenv_env_oldpath; and set -gx PATH $__vjenv_env_oldpath
    set -e __vjenv_env_names
    set -e __vjenv_env_olds
    set -e __vjenv_env_oldpath
    set -e VJENV_ENV_ROOT
end

function __vjenv_pick_shell
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

function __vjenv_refresh --on-variable PWD
    {exe} env fish | source
{gate}
    if set -q __vjenv_env_pending
        set -l dir $__vjenv_env_pending
        set -e __vjenv_env_pending
        if status is-interactive; and test "$dir" != "$__vjenv_env_asked"
            set -g __vjenv_env_asked $dir
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
    end
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

    fn init(gated: Option<&str>) -> String {
        fish(&PathBuf::from("/nix/store/abc-vjenv/bin/vjenv"), gated)
    }

    #[test]
    fn defines_the_functions_the_emitted_environment_calls() {
        let text = init(None);
        for f in [
            "__vjenv_env_set",
            "__vjenv_env_path",
            "__vjenv_env_unload",
            "__vjenv_pick_shell",
            "__vjenv_refresh",
        ] {
            assert!(text.contains(&format!("function {f}")), "missing {f}");
        }
    }

    #[test]
    fn hooks_the_directory_change_and_primes_itself() {
        let text = init(None);
        assert!(text.contains("--on-variable PWD"));
        assert!(text.trim_end().ends_with("__vjenv_refresh"));
    }

    #[test]
    fn the_gated_directory_is_only_juggled_when_there_is_one() {
        assert!(!init(None).contains("string match -v"));
        let text = init(Some("/nix/store/xyz-gated/bin"));
        assert!(text.contains("string match -v -- '/nix/store/xyz-gated/bin' $PATH"));
        assert!(text.contains("set -q VJENV_IDENTITY; and set -gx PATH '/nix/store/xyz-gated/bin' $PATH"));
    }

    #[test]
    fn use_is_told_which_shell_to_emit_for() {
        assert!(init(None).contains("use --shell fish"));
    }

    #[test]
    fn a_path_needing_quoting_cannot_break_out() {
        let text = fish(&PathBuf::from("/tmp/it's here/vjenv"), Some("/g'd"));
        assert!(text.contains(r"'/tmp/it\'s here/vjenv'"));
        assert!(text.contains(r"'/g\'d'"));
    }
}
