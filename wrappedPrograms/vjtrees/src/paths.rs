#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Category {
    Owned,
    Shared,
    Mixed,
}

pub fn matches(file: &str, patterns: &[String]) -> bool {
    patterns.iter().any(|pattern| {
        if let Some(prefix) = pattern.strip_suffix('/') {
            file == prefix || file.starts_with(&format!("{prefix}/"))
        } else {
            file == pattern
        }
    })
}

pub fn is_owned(file: &str, owned: &[String]) -> bool {
    matches(file, owned)
}

pub fn is_shared(file: &str, owned: &[String]) -> bool {
    !is_owned(file, owned)
}

pub fn breaks_dependents(file: &str, fragile: &[String]) -> bool {
    matches(file, fragile)
}

pub fn categorize(files: &[String], owned: &[String]) -> Category {
    if files.is_empty() {
        return Category::Owned;
    }

    let has_owned = files.iter().any(|f| is_owned(f, owned));
    let has_shared = files.iter().any(|f| is_shared(f, owned));

    match (has_shared, has_owned) {
        (true, true) => Category::Mixed,
        (true, false) => Category::Shared,
        _ => Category::Owned,
    }
}
