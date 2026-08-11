use crate::config::Identity;
use crate::emit::EnvOp;
use crate::paths::Dirs;
use serde::Serialize;
use std::path::Path;

pub const MANAGED: &[&str] = &[
    "VJENV_IDENTITY",
    "VJENV_ROOT",
    "VJENV_PINNED",
    "GIT_CONFIG_COUNT",
    "GIT_CONFIG_KEY_0",
    "GIT_CONFIG_VALUE_0",
    "GIT_CONFIG_KEY_1",
    "GIT_CONFIG_VALUE_1",
    "GIT_CONFIG_KEY_2",
    "GIT_CONFIG_VALUE_2",
    "GIT_SSH_COMMAND",
    "GH_CONFIG_DIR",
    "JJ_CONFIG",
];

const GIT_SLOTS: usize = 3;

pub struct Context<'a> {
    pub dirs: &'a Dirs,
    pub root: Option<&'a Path>,
    pub id: Option<&'a str>,
    pub identity: Option<&'a Identity>,
    pub pinned: bool,
    pub jj_config_current: Option<&'a str>,
}

pub fn jj_base(current: Option<&str>, runtime: &Path) -> Option<String> {
    let kept: Vec<&str> = current?
        .split(':')
        .filter(|p| !p.is_empty() && !Path::new(p).starts_with(runtime))
        .collect();
    (!kept.is_empty()).then(|| kept.join(":"))
}

#[derive(Serialize)]
struct JjUser<'a> {
    #[serde(skip_serializing_if = "Option::is_none")]
    name: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    email: Option<&'a str>,
}

#[derive(Serialize)]
struct JjConfig<'a> {
    user: JjUser<'a>,
}

pub fn jj_config_toml(identity: &Identity) -> String {
    let cfg = JjConfig {
        user: JjUser {
            name: identity.name.as_deref(),
            email: identity.email.as_deref(),
        },
    };
    toml::to_string_pretty(&cfg).expect("jj config is always serializable")
}

pub fn env_ops(ctx: &Context) -> Vec<EnvOp> {
    let mut ops = Vec::with_capacity(MANAGED.len());
    let base = jj_base(ctx.jj_config_current, &ctx.dirs.runtime);

    let (Some(id), Some(identity)) = (ctx.id, ctx.identity) else {
        for name in MANAGED {
            if *name == "JJ_CONFIG" {
                continue;
            }
            ops.push(EnvOp::unset(*name));
        }
        ops.push(match &base {
            Some(b) => EnvOp::set("JJ_CONFIG", b),
            None => EnvOp::unset("JJ_CONFIG"),
        });
        return ops;
    };

    ops.push(EnvOp::set("VJENV_IDENTITY", id));
    ops.push(match ctx.root {
        Some(r) => EnvOp::set("VJENV_ROOT", r.to_string_lossy()),
        None => EnvOp::unset("VJENV_ROOT"),
    });
    ops.push(if ctx.pinned {
        EnvOp::set("VJENV_PINNED", "1")
    } else {
        EnvOp::unset("VJENV_PINNED")
    });

    let ssh_command = identity
        .ssh_key
        .as_ref()
        .map(|k| format!("ssh -i {} -o IdentitiesOnly=yes", k.display()));
    let mut pairs: Vec<(&str, String)> = Vec::with_capacity(GIT_SLOTS);
    if let Some(name) = &identity.name {
        pairs.push(("user.name", name.clone()));
    }
    if let Some(email) = &identity.email {
        pairs.push(("user.email", email.clone()));
    }
    if let Some(cmd) = &ssh_command {
        pairs.push(("core.sshCommand", cmd.clone()));
    }

    ops.push(EnvOp::set("GIT_CONFIG_COUNT", pairs.len().to_string()));
    for slot in 0..GIT_SLOTS {
        match pairs.get(slot) {
            Some((key, value)) => {
                ops.push(EnvOp::set(format!("GIT_CONFIG_KEY_{slot}"), *key));
                ops.push(EnvOp::set(format!("GIT_CONFIG_VALUE_{slot}"), value.clone()));
            }
            None => {
                ops.push(EnvOp::unset(format!("GIT_CONFIG_KEY_{slot}")));
                ops.push(EnvOp::unset(format!("GIT_CONFIG_VALUE_{slot}")));
            }
        }
    }

    ops.push(match &ssh_command {
        Some(cmd) => EnvOp::set("GIT_SSH_COMMAND", cmd.clone()),
        None => EnvOp::unset("GIT_SSH_COMMAND"),
    });

    ops.push(EnvOp::set(
        "GH_CONFIG_DIR",
        ctx.dirs.gh_config(id).to_string_lossy(),
    ));

    let jj_file = ctx.dirs.jj_config(id);
    let jj_value = match &base {
        Some(b) => format!("{b}:{}", jj_file.display()),
        None => jj_file.display().to_string(),
    };
    ops.push(EnvOp::set("JJ_CONFIG", jj_value));

    ops
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeSet;
    use std::path::PathBuf;

    fn dirs() -> Dirs {
        Dirs {
            home: PathBuf::from("/h"),
            config: PathBuf::from("/h/.config/vjenv"),
            state: PathBuf::from("/h/.local/state/vjenv"),
            data: PathBuf::from("/h/.local/share/vjenv"),
            runtime: PathBuf::from("/run/user/1000/vjenv"),
        }
    }

    fn full() -> Identity {
        Identity {
            name: Some("Vimjoyer".into()),
            email: Some("vimjoyer@gmail.com".into()),
            ssh_key: Some(PathBuf::from("/h/.ssh/id_rsa_vimjoyer")),
        }
    }

    fn ops_for(identity: Option<&Identity>, jj_current: Option<&str>) -> Vec<EnvOp> {
        let d = dirs();
        env_ops(&Context {
            dirs: &d,
            root: Some(Path::new("/h/Projects/secretspec")),
            id: identity.map(|_| "vimjoyer"),
            identity,
            pinned: false,
            jj_config_current: jj_current,
        })
    }

    fn value<'a>(ops: &'a [EnvOp], name: &str) -> Option<&'a str> {
        ops.iter().find_map(|o| match o {
            EnvOp::Set(n, v) if n == name => Some(v.as_str()),
            _ => None,
        })
    }

    fn is_unset(ops: &[EnvOp], name: &str) -> bool {
        ops.iter().any(|o| matches!(o, EnvOp::Unset(n) if n == name))
    }

    #[test]
    fn every_managed_variable_is_always_accounted_for() {
        for identity in [Some(&full()), None] {
            let ops = ops_for(identity, None);
            let emitted: BTreeSet<&str> = ops
                .iter()
                .map(|o| match o {
                    EnvOp::Set(n, _) | EnvOp::Unset(n) => n.as_str(),
                })
                .collect();
            let managed: BTreeSet<&str> = MANAGED.iter().copied().collect();
            assert_eq!(emitted, managed, "identity present: {}", identity.is_some());
            assert_eq!(ops.len(), MANAGED.len(), "a variable was emitted twice");
        }
    }

    #[test]
    fn a_full_identity_populates_all_three_git_slots() {
        let ops = ops_for(Some(&full()), None);
        assert_eq!(value(&ops, "VJENV_IDENTITY"), Some("vimjoyer"));
        assert_eq!(value(&ops, "VJENV_ROOT"), Some("/h/Projects/secretspec"));
        assert_eq!(value(&ops, "GIT_CONFIG_COUNT"), Some("3"));
        assert_eq!(value(&ops, "GIT_CONFIG_KEY_0"), Some("user.name"));
        assert_eq!(value(&ops, "GIT_CONFIG_VALUE_0"), Some("Vimjoyer"));
        assert_eq!(value(&ops, "GIT_CONFIG_KEY_1"), Some("user.email"));
        assert_eq!(value(&ops, "GIT_CONFIG_VALUE_1"), Some("vimjoyer@gmail.com"));
        assert_eq!(value(&ops, "GIT_CONFIG_KEY_2"), Some("core.sshCommand"));
        assert_eq!(
            value(&ops, "GIT_SSH_COMMAND"),
            Some("ssh -i /h/.ssh/id_rsa_vimjoyer -o IdentitiesOnly=yes")
        );
        assert_eq!(
            value(&ops, "GH_CONFIG_DIR"),
            Some("/h/.local/share/vjenv/vimjoyer/gh")
        );
        assert!(is_unset(&ops, "VJENV_PINNED"));
    }

    #[test]
    fn an_identity_without_a_key_unsets_the_ssh_command_and_the_spare_slot() {
        let keyless = Identity {
            ssh_key: None,
            ..full()
        };
        let ops = ops_for(Some(&keyless), None);
        assert_eq!(value(&ops, "GIT_CONFIG_COUNT"), Some("2"));
        assert!(is_unset(&ops, "GIT_CONFIG_KEY_2"));
        assert!(is_unset(&ops, "GIT_CONFIG_VALUE_2"));
        assert!(is_unset(&ops, "GIT_SSH_COMMAND"));
    }

    #[test]
    fn an_identity_with_only_a_key_still_indexes_from_zero() {
        let only_key = Identity {
            name: None,
            email: None,
            ssh_key: Some(PathBuf::from("/h/.ssh/k")),
        };
        let ops = ops_for(Some(&only_key), None);
        assert_eq!(value(&ops, "GIT_CONFIG_COUNT"), Some("1"));
        assert_eq!(value(&ops, "GIT_CONFIG_KEY_0"), Some("core.sshCommand"));
        assert!(is_unset(&ops, "GIT_CONFIG_KEY_1"));
    }

    #[test]
    fn no_identity_clears_everything() {
        let ops = ops_for(None, None);
        for name in MANAGED {
            assert!(is_unset(&ops, name), "{name} should have been unset");
        }
    }

    #[test]
    fn pinning_is_reported() {
        let d = dirs();
        let id = full();
        let ops = env_ops(&Context {
            dirs: &d,
            root: Some(Path::new("/h/Projects/secretspec")),
            id: Some("vimjoyer"),
            identity: Some(&id),
            pinned: true,
            jj_config_current: None,
        });
        assert_eq!(value(&ops, "VJENV_PINNED"), Some("1"));
    }

    #[test]
    fn jj_config_layers_on_top_of_an_inherited_base() {
        let ops = ops_for(Some(&full()), Some("/nix/store/abc-jj/jj-config.toml"));
        assert_eq!(
            value(&ops, "JJ_CONFIG"),
            Some("/nix/store/abc-jj/jj-config.toml:/run/user/1000/vjenv/vimjoyer.jj.toml")
        );
    }

    #[test]
    fn a_previous_identity_fragment_is_stripped_rather_than_stacked() {
        let ops = ops_for(
            Some(&full()),
            Some("/nix/store/abc-jj/jj-config.toml:/run/user/1000/vjenv/goxore.jj.toml"),
        );
        assert_eq!(
            value(&ops, "JJ_CONFIG"),
            Some("/nix/store/abc-jj/jj-config.toml:/run/user/1000/vjenv/vimjoyer.jj.toml")
        );
    }

    #[test]
    fn dropping_the_identity_restores_the_bare_base() {
        let ops = ops_for(
            None,
            Some("/nix/store/abc-jj/jj-config.toml:/run/user/1000/vjenv/goxore.jj.toml"),
        );
        assert_eq!(
            value(&ops, "JJ_CONFIG"),
            Some("/nix/store/abc-jj/jj-config.toml")
        );
    }

    #[test]
    fn jj_base_handles_empty_and_vjenv_only_values() {
        let rt = Path::new("/run/user/1000/vjenv");
        assert_eq!(jj_base(None, rt), None);
        assert_eq!(jj_base(Some(""), rt), None);
        assert_eq!(jj_base(Some("/run/user/1000/vjenv/goxore.jj.toml"), rt), None);
        assert_eq!(jj_base(Some("/a:/b"), rt), Some("/a:/b".into()));
        assert_eq!(jj_base(Some("/a::/b"), rt), Some("/a:/b".into()));
    }

    #[test]
    fn jj_fragment_escapes_awkward_names() {
        let weird = Identity {
            name: Some(r#"Yur"ii \ the "great""#.into()),
            email: Some("y@example.com".into()),
            ssh_key: None,
        };
        let text = jj_config_toml(&weird);
        let parsed: toml::Value = toml::from_str(&text).expect("must be valid toml");
        assert_eq!(
            parsed["user"]["name"].as_str(),
            Some(r#"Yur"ii \ the "great""#)
        );
    }

    #[test]
    fn jj_fragment_omits_missing_fields() {
        let partial = Identity {
            name: None,
            email: Some("y@example.com".into()),
            ssh_key: None,
        };
        let parsed: toml::Value = toml::from_str(&jj_config_toml(&partial)).unwrap();
        assert!(parsed["user"].get("name").is_none());
        assert_eq!(parsed["user"]["email"].as_str(), Some("y@example.com"));
    }
}
