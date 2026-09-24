pub const VAR: &str = "VJENV_ENV_UNDO";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Restore {
    pub name: String,
    pub previous: Option<String>,
}

impl Restore {
    pub fn set(name: impl Into<String>, previous: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            previous: Some(previous.into()),
        }
    }

    pub fn absent(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            previous: None,
        }
    }
}

fn escape(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    for c in value.chars() {
        match c {
            '\\' => out.push_str(r"\\"),
            '\n' => out.push_str(r"\n"),
            _ => out.push(c),
        }
    }
    out
}

fn unescape(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut chars = text.chars();
    while let Some(c) = chars.next() {
        if c != '\\' {
            out.push(c);
            continue;
        }
        match chars.next() {
            Some('n') => out.push('\n'),
            Some('\\') => out.push('\\'),
            Some(other) => out.push(other),
            None => break,
        }
    }
    out
}

pub fn encode(entries: &[Restore]) -> String {
    entries
        .iter()
        .map(|e| match &e.previous {
            Some(v) => format!("{}={}", e.name, escape(v)),
            None => e.name.clone(),
        })
        .collect::<Vec<_>>()
        .join("\n")
}

pub fn decode(text: &str) -> Vec<Restore> {
    text.split('\n')
        .filter(|line| !line.is_empty())
        .map(|line| match line.split_once('=') {
            Some((name, value)) => Restore::set(name, unescape(value)),
            None => Restore::absent(line),
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips_values_and_absences() {
        let entries = vec![
            Restore::set("PATH", "/a:/b"),
            Restore::absent("CARGO_HOME"),
            Restore::set("EMPTY", ""),
        ];
        assert_eq!(decode(&encode(&entries)), entries);
    }

    #[test]
    fn an_empty_log_decodes_to_nothing() {
        assert!(decode("").is_empty());
        assert_eq!(encode(&[]), "");
    }

    #[test]
    fn newlines_and_backslashes_survive() {
        let entries = vec![
            Restore::set("SCRIPT", "line1\nline2"),
            Restore::set("WIN", r"C:\path\to"),
            Restore::set("TRAP", r"looks\nlike a newline"),
            Restore::set("TRAILING", "ends with a backslash \\"),
        ];
        let text = encode(&entries);
        assert_eq!(
            text.lines().count(),
            entries.len(),
            "each record must stay on one line: {text:?}"
        );
        assert_eq!(decode(&text), entries);
    }

    #[test]
    fn values_may_contain_equals_signs() {
        let entries = vec![Restore::set("OPTS", "a=b=c")];
        assert_eq!(decode(&encode(&entries)), entries);
    }

    #[test]
    fn an_empty_value_is_distinct_from_an_absent_variable() {
        assert_eq!(encode(&[Restore::set("X", "")]), "X=");
        assert_eq!(encode(&[Restore::absent("X")]), "X");
        assert_eq!(decode("X="), vec![Restore::set("X", "")]);
        assert_eq!(decode("X"), vec![Restore::absent("X")]);
    }
}
