use std::path::PathBuf;

pub fn dir(var: &str, app: &str, fallback: impl FnOnce() -> PathBuf) -> PathBuf {
    match std::env::var_os(var) {
        Some(v) if !v.is_empty() => PathBuf::from(v).join(app),
        _ => fallback(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn an_unset_or_empty_variable_falls_back() {
        unsafe { std::env::remove_var("VJ_TEST_XDG") };
        assert_eq!(
            dir("VJ_TEST_XDG", "app", || PathBuf::from("/fb")),
            PathBuf::from("/fb")
        );

        unsafe { std::env::set_var("VJ_TEST_XDG", "") };
        assert_eq!(
            dir("VJ_TEST_XDG", "app", || PathBuf::from("/fb")),
            PathBuf::from("/fb")
        );
    }

    #[test]
    fn a_set_variable_is_joined_with_the_application_name() {
        unsafe { std::env::set_var("VJ_TEST_XDG2", "/xdg") };
        assert_eq!(
            dir("VJ_TEST_XDG2", "vjenv", || PathBuf::from("/fb")),
            PathBuf::from("/xdg/vjenv")
        );
    }
}
