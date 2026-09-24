use crate::devshell::DevEnv;
use crate::emit::EnvOp;
use crate::undo::{self, Restore};
use std::collections::BTreeMap;

pub type Env = BTreeMap<String, String>;

pub const ROOT_VAR: &str = "VJENV_ENV_ROOT";
pub const STAMP_VAR: &str = "VJENV_ENV_STAMP";
pub const FAILED_VAR: &str = "VJENV_ENV_FAILED";

pub const MARKERS: &[&str] = &[ROOT_VAR, STAMP_VAR, FAILED_VAR, undo::VAR];

fn previous(current: &Env) -> Vec<Restore> {
    current
        .get(undo::VAR)
        .map(|v| undo::decode(v))
        .unwrap_or_default()
}

pub fn base(current: &Env) -> Env {
    let mut env = current.clone();
    for r in previous(current) {
        match r.previous {
            Some(v) => env.insert(r.name, v),
            None => env.remove(&r.name),
        };
    }
    for name in MARKERS {
        env.remove(*name);
    }
    env
}

pub struct Transition {
    pub ops: Vec<EnvOp>,
    pub base_path: String,
    pub dev_path: Vec<String>,
}

pub struct Loading<'a> {
    pub env: &'a DevEnv,
    pub root: &'a str,
    pub stamp: &'a str,
}

pub fn transition(current: &Env, next: Option<Loading<'_>>) -> Transition {
    let base = base(current);
    let base_path = base.get("PATH").cloned().unwrap_or_default();
    let keeping: Vec<&str> = next
        .as_ref()
        .map(|n| n.env.vars.iter().map(|(k, _)| k.as_str()).collect())
        .unwrap_or_default();

    let mut ops = Vec::new();
    for r in previous(current) {
        if r.name == "PATH" || keeping.contains(&r.name.as_str()) {
            continue;
        }
        ops.push(match r.previous {
            Some(v) => EnvOp::set(r.name, v),
            None => EnvOp::unset(r.name),
        });
    }

    let Some(next) = next else {
        ops.push(EnvOp::unset(ROOT_VAR));
        ops.push(EnvOp::unset(STAMP_VAR));
        ops.push(EnvOp::unset(undo::VAR));
        return Transition {
            ops,
            base_path,
            dev_path: Vec::new(),
        };
    };

    let mut log = Vec::with_capacity(next.env.vars.len() + 1);
    for (k, v) in &next.env.vars {
        ops.push(EnvOp::set(k.clone(), v.clone()));
        log.push(Restore {
            name: k.clone(),
            previous: base.get(k).cloned(),
        });
    }
    log.push(Restore::set("PATH", base_path.clone()));

    ops.push(EnvOp::set(ROOT_VAR, next.root));
    ops.push(EnvOp::set(STAMP_VAR, next.stamp));
    ops.push(EnvOp::set(undo::VAR, undo::encode(&log)));

    Transition {
        ops,
        base_path,
        dev_path: next.env.path.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn env_of(pairs: &[(&str, &str)], previous: &[Restore]) -> Env {
        let mut env: Env = pairs
            .iter()
            .map(|(k, v)| (k.to_string(), v.to_string()))
            .collect();
        if !previous.is_empty() {
            env.insert(undo::VAR.into(), undo::encode(previous));
        }
        env
    }

    fn dev(vars: &[(&str, &str)], path: &[&str]) -> DevEnv {
        DevEnv {
            vars: vars
                .iter()
                .map(|(k, v)| (k.to_string(), v.to_string()))
                .collect(),
            path: path.iter().map(|s| s.to_string()).collect(),
        }
    }

    fn value<'a>(ops: &'a [EnvOp], name: &str) -> Option<&'a str> {
        ops.iter().find_map(|o| match o {
            EnvOp::Set(n, v) if n == name => Some(v.as_str()),
            _ => None,
        })
    }

    fn unsets(ops: &[EnvOp], name: &str) -> bool {
        ops.iter()
            .any(|o| matches!(o, EnvOp::Unset(n) if n == name))
    }

    fn logged(ops: &[EnvOp]) -> Vec<Restore> {
        undo::decode(value(ops, undo::VAR).expect("an undo log must be recorded"))
    }

    #[test]
    fn loading_records_the_previous_values_it_shadows() {
        let current = env_of(&[("PATH", "/usr/bin"), ("CARGO_HOME", "/mine")], &[]);
        let d = dev(&[("CARGO_HOME", "/dev"), ("RUSTUP", "/r")], &["/nix/a/bin"]);

        let t = transition(
            &current,
            Some(Loading {
                env: &d,
                root: "/p",
                stamp: "s1",
            }),
        );

        assert_eq!(value(&t.ops, "CARGO_HOME"), Some("/dev"));
        assert_eq!(value(&t.ops, ROOT_VAR), Some("/p"));
        assert_eq!(value(&t.ops, STAMP_VAR), Some("s1"));
        assert_eq!(t.base_path, "/usr/bin");
        assert_eq!(t.dev_path, vec!["/nix/a/bin"]);

        let log = logged(&t.ops);
        assert!(log.contains(&Restore::set("CARGO_HOME", "/mine")));
        assert!(log.contains(&Restore::absent("RUSTUP")));
        assert!(log.contains(&Restore::set("PATH", "/usr/bin")));
    }

    #[test]
    fn unloading_restores_every_shadowed_value_and_clears_the_markers() {
        let current = env_of(
            &[("PATH", "/nix/a/bin:/usr/bin"), ("CARGO_HOME", "/dev")],
            &[
                Restore::set("CARGO_HOME", "/mine"),
                Restore::absent("RUSTUP"),
                Restore::set("PATH", "/usr/bin"),
            ],
        );

        let t = transition(&current, None);

        assert_eq!(value(&t.ops, "CARGO_HOME"), Some("/mine"));
        assert!(unsets(&t.ops, "RUSTUP"));
        assert!(unsets(&t.ops, ROOT_VAR));
        assert!(unsets(&t.ops, STAMP_VAR));
        assert!(unsets(&t.ops, undo::VAR));
        assert_eq!(t.base_path, "/usr/bin", "PATH must come back from the log");
        assert!(t.dev_path.is_empty());
    }

    #[test]
    fn moving_between_projects_never_leaks_the_first_environment() {
        let current = env_of(
            &[
                ("PATH", "/nix/a/bin:/usr/bin"),
                ("OLD_ONLY", "/a"),
                ("SHARED", "/a"),
            ],
            &[
                Restore::absent("OLD_ONLY"),
                Restore::set("SHARED", "/original"),
                Restore::set("PATH", "/usr/bin"),
            ],
        );
        let d = dev(&[("SHARED", "/b"), ("NEW_ONLY", "/b")], &["/nix/b/bin"]);

        let t = transition(
            &current,
            Some(Loading {
                env: &d,
                root: "/q",
                stamp: "s2",
            }),
        );

        assert!(
            unsets(&t.ops, "OLD_ONLY"),
            "the first project's variable must go"
        );
        assert_eq!(value(&t.ops, "SHARED"), Some("/b"));
        assert_eq!(
            t.base_path, "/usr/bin",
            "the new PATH must build on the pristine one, not the stacked one"
        );

        let log = logged(&t.ops);
        assert!(
            log.contains(&Restore::set("SHARED", "/original")),
            "the log must remember the pristine value, not the first project's: {log:?}"
        );
        assert!(log.contains(&Restore::absent("NEW_ONLY")));
        assert!(
            !log.iter().any(|r| r.name == "OLD_ONLY"),
            "a variable the new environment does not set has no place in the log"
        );
    }

    #[test]
    fn a_variable_kept_by_both_is_not_restored_and_reset() {
        let current = env_of(
            &[("PATH", "/usr/bin"), ("SHARED", "/a")],
            &[
                Restore::set("SHARED", "/original"),
                Restore::set("PATH", "/usr/bin"),
            ],
        );
        let d = dev(&[("SHARED", "/b")], &[]);

        let t = transition(
            &current,
            Some(Loading {
                env: &d,
                root: "/q",
                stamp: "s",
            }),
        );

        let sets: Vec<_> = t
            .ops
            .iter()
            .filter(|o| matches!(o, EnvOp::Set(n, _) if n == "SHARED"))
            .collect();
        assert_eq!(
            sets.len(),
            1,
            "SHARED must be written exactly once: {sets:?}"
        );
        assert_eq!(value(&t.ops, "SHARED"), Some("/b"));
    }

    #[test]
    fn unloading_without_a_log_still_clears_the_markers() {
        let current = env_of(&[("PATH", "/usr/bin")], &[]);
        let t = transition(&current, None);
        assert!(unsets(&t.ops, ROOT_VAR));
        assert!(unsets(&t.ops, undo::VAR));
        assert_eq!(t.base_path, "/usr/bin");
    }

    #[test]
    fn the_log_round_trips_through_a_reload() {
        let current = env_of(
            &[("PATH", "/usr/bin"), ("ODD", "has=equals and\nnewline")],
            &[],
        );
        let d = dev(&[("ODD", "/dev")], &[]);

        let first = transition(
            &current,
            Some(Loading {
                env: &d,
                root: "/p",
                stamp: "s",
            }),
        );
        let log = logged(&first.ops);
        let back = transition(&env_of(&[("PATH", "/usr/bin")], &log), None);

        assert_eq!(value(&back.ops, "ODD"), Some("has=equals and\nnewline"));
    }
}
