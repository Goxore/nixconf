use std::fmt::Write as _;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EnvOp {
    Set(String, String),
    Unset(String),
}

impl EnvOp {
    pub fn set(name: impl Into<String>, value: impl Into<String>) -> Self {
        EnvOp::Set(name.into(), value.into())
    }
    pub fn unset(name: impl Into<String>) -> Self {
        EnvOp::Unset(name.into())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Shell {
    Fish,
    Posix,
}

impl Shell {
    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "fish" => Some(Shell::Fish),
            "posix" | "sh" | "bash" | "zsh" => Some(Shell::Posix),
            _ => None,
        }
    }
}

pub fn quote(value: &str, shell: Shell) -> String {
    let mut out = String::with_capacity(value.len() + 2);
    out.push('\'');
    for c in value.chars() {
        match (shell, c) {
            (Shell::Fish, '\'') => out.push_str("\\'"),
            (Shell::Fish, '\\') => out.push_str("\\\\"),
            (Shell::Posix, '\'') => out.push_str("'\\''"),
            _ => out.push(c),
        }
    }
    out.push('\'');
    out
}

pub fn render(ops: &[EnvOp], shell: Shell) -> String {
    let mut out = String::new();
    for op in ops {
        match (shell, op) {
            (Shell::Fish, EnvOp::Set(n, v)) => {
                let _ = writeln!(out, "set -gx {n} {}", quote(v, shell));
            }
            (Shell::Fish, EnvOp::Unset(n)) => {
                let _ = writeln!(out, "set -e {n}");
            }
            (Shell::Posix, EnvOp::Set(n, v)) => {
                let _ = writeln!(out, "export {n}={}", quote(v, shell));
            }
            (Shell::Posix, EnvOp::Unset(n)) => {
                let _ = writeln!(out, "unset {n}");
            }
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    const NASTY: &[&str] = &[
        "plain",
        "with space",
        "it's",
        "\"double\"",
        "back\\slash",
        "both'\\mixed",
        "$HOME and `cmd` and $(cmd)",
        "semi;colon && pipe|",
        "new\nline",
        "tab\there",
        "-leading-dash",
        "--flag",
        "",
        "emoji 🐟 and ünïcode",
        "ssh -i /home/yurii/.ssh/id_rsa -o IdentitiesOnly=yes",
    ];

    fn unquote(quoted: &str, shell: Shell) -> String {
        let inner = quoted
            .strip_prefix('\'')
            .and_then(|s| s.strip_suffix('\''))
            .expect("quoted value must be wrapped in single quotes");
        let mut out = String::new();
        let mut chars = inner.chars();
        while let Some(c) = chars.next() {
            match (shell, c) {
                (Shell::Fish, '\\') => out.push(chars.next().expect("dangling escape")),
                (Shell::Posix, '\'') => {
                    assert_eq!(chars.next(), Some('\\'));
                    assert_eq!(chars.next(), Some('\''));
                    assert_eq!(chars.next(), Some('\''));
                    out.push('\'');
                }
                _ => out.push(c),
            }
        }
        out
    }

    #[test]
    fn quoting_round_trips_for_both_shells() {
        for shell in [Shell::Fish, Shell::Posix] {
            for value in NASTY {
                let q = quote(value, shell);
                assert_eq!(&unquote(&q, shell), value, "{shell:?} mangled {value:?}");
            }
        }
    }

    #[test]
    fn fish_escapes_quote_and_backslash_only() {
        assert_eq!(quote("it's", Shell::Fish), r"'it\'s'");
        assert_eq!(quote(r"a\b", Shell::Fish), r"'a\\b'");
        assert_eq!(quote("$HOME", Shell::Fish), "'$HOME'");
    }

    #[test]
    fn posix_breaks_out_for_a_quote() {
        assert_eq!(quote("it's", Shell::Posix), r#"'it'\''s'"#);
        assert_eq!(quote(r"a\b", Shell::Posix), r"'a\b'");
    }

    #[test]
    fn renders_sets_and_unsets_per_shell() {
        let ops = vec![
            EnvOp::set("VJENV_IDENTITY", "goxore"),
            EnvOp::unset("VJENV_PINNED"),
        ];
        assert_eq!(
            render(&ops, Shell::Fish),
            "set -gx VJENV_IDENTITY 'goxore'\nset -e VJENV_PINNED\n"
        );
        assert_eq!(
            render(&ops, Shell::Posix),
            "export VJENV_IDENTITY='goxore'\nunset VJENV_PINNED\n"
        );
    }

    #[test]
    fn every_rendered_line_stands_alone_even_with_newlines_in_values() {
        let ops = vec![EnvOp::set("X", "a\nb")];
        for shell in [Shell::Fish, Shell::Posix] {
            let text = render(&ops, shell);
            assert!(text.ends_with('\n'));
            assert_eq!(text.matches('\n').count(), 2);
        }
    }

    #[test]
    fn shell_names_parse() {
        assert_eq!(Shell::parse("fish"), Some(Shell::Fish));
        assert_eq!(Shell::parse("posix"), Some(Shell::Posix));
        assert_eq!(Shell::parse("bash"), Some(Shell::Posix));
        assert_eq!(Shell::parse("nonsense"), None);
    }
}
