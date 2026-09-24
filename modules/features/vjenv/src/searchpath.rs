pub const GATED_DIR_VAR: &str = "VJENV_GATED_DIR";

pub fn split(path: &str) -> impl Iterator<Item = &str> {
    path.split(':').filter(|p| !p.is_empty())
}

pub fn compose(current: &str, dev: &[String], gated: Option<&str>, gate: bool) -> String {
    let leading = gate.then_some(gated).flatten();
    let entries = leading.into_iter().chain(
        dev.iter()
            .map(String::as_str)
            .chain(split(current))
            .filter(|p| Some(*p) != gated),
    );

    let mut kept: Vec<&str> = Vec::new();
    for entry in entries {
        if !entry.is_empty() && !kept.contains(&entry) {
            kept.push(entry);
        }
    }
    kept.join(":")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dev(entries: &[&str]) -> Vec<String> {
        entries.iter().map(|s| s.to_string()).collect()
    }

    const GATED: &str = "/etc/vjenv/gated/bin";

    #[test]
    fn the_gated_directory_leads_when_an_identity_is_active() {
        let out = compose(
            "/usr/bin:/bin",
            &dev(&["/nix/store/a/bin"]),
            Some(GATED),
            true,
        );
        assert_eq!(out, format!("{GATED}:/nix/store/a/bin:/usr/bin:/bin"));
    }

    #[test]
    fn the_gated_directory_is_removed_when_no_identity_is_active() {
        let current = format!("{GATED}:/usr/bin");
        assert_eq!(compose(&current, &[], Some(GATED), false), "/usr/bin");
    }

    #[test]
    fn an_inherited_gated_entry_is_never_duplicated() {
        let current = format!("/usr/bin:{GATED}:/bin");
        let out = compose(&current, &[], Some(GATED), true);
        assert_eq!(out, format!("{GATED}:/usr/bin:/bin"));
        assert_eq!(
            out.matches(GATED).count(),
            1,
            "the gated directory must appear exactly once"
        );
    }

    #[test]
    fn repeated_entries_collapse_to_their_first_position() {
        let out = compose("/usr/bin:/bin:/usr/bin", &dev(&["/bin"]), None, false);
        assert_eq!(out, "/bin:/usr/bin");
    }

    #[test]
    fn empty_segments_are_dropped() {
        assert_eq!(
            compose("/usr/bin::/bin:", &[], None, false),
            "/usr/bin:/bin"
        );
        assert_eq!(compose("", &dev(&["/a"]), None, false), "/a");
        assert_eq!(compose("", &[], None, false), "");
    }

    #[test]
    fn the_dev_environment_cannot_shadow_the_gate() {
        let out = compose(
            "/usr/bin",
            &dev(&[GATED, "/nix/store/a/bin"]),
            Some(GATED),
            true,
        );
        assert!(
            out.starts_with(&format!("{GATED}:")),
            "gate must lead regardless of the dev environment: {out}"
        );
        assert_eq!(out.matches(GATED).count(), 1);
    }

    #[test]
    fn without_a_configured_gate_nothing_is_prepended_or_stripped() {
        let current = format!("{GATED}:/usr/bin");
        assert_eq!(compose(&current, &[], None, true), current);
        assert_eq!(compose(&current, &[], None, false), current);
    }
}
