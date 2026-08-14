use std::fs;
use std::path::Path;

const MUTATING_CALLS: &[&str] = &[
    "jj.new_change(",
    "jj.describe(",
    "jj.abandon(",
    "jj.workspace_add(",
    "jj.workspace_forget(",
    "jj.op_restore(",
    "jj.rebase(",
];

const ALLOWED_OUTSIDE_GUARDED: &[(&str, &str)] = &[
    ("init.rs", "establish_invariant"),
    ("history.rs", "resolve_target"),
];

fn guarded_spans(text: &str) -> Vec<(usize, usize)> {
    let bytes = text.as_bytes();
    let mut spans = Vec::new();
    let mut from = 0;

    while let Some(hit) = text[from..].find("guarded(") {
        let open = from + hit + "guarded(".len() - 1;
        let mut depth = 0usize;
        let mut in_string = false;
        let mut escaped = false;
        let mut at = open;

        while at < bytes.len() {
            let byte = bytes[at];

            if in_string {
                if escaped {
                    escaped = false;
                } else if byte == b'\\' {
                    escaped = true;
                } else if byte == b'"' {
                    in_string = false;
                }
            } else {
                match byte {
                    b'"' => in_string = true,
                    b'(' => depth += 1,
                    b')' => {
                        depth -= 1;
                        if depth == 0 {
                            break;
                        }
                    }
                    _ => {}
                }
            }

            at += 1;
        }

        assert!(
            depth == 0 && at < bytes.len(),
            "unbalanced parentheses after a guarded( at byte {open} — \
             the scan below cannot be trusted until this parses"
        );

        spans.push((open, at));
        from = open + 1;
    }

    spans
}

fn enclosing_fn(text: &str, offset: usize) -> String {
    text[..offset]
        .rmatch_indices("fn ")
        .find_map(|(at, _)| {
            let name: String = text[at + 3..]
                .chars()
                .take_while(|c| c.is_alphanumeric() || *c == '_')
                .collect();
            (!name.is_empty()).then_some(name)
        })
        .unwrap_or_else(|| "<unknown>".to_string())
}

fn line_of(text: &str, offset: usize) -> usize {
    text[..offset].lines().count()
}

#[test]
fn every_mutation_in_the_commands_goes_through_guarded() {
    let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("src/commands");
    let mut escapes = Vec::new();
    let mut scanned = 0;

    for entry in fs::read_dir(&dir).expect("read src/commands") {
        let path = entry.expect("dir entry").path();
        if path.extension().and_then(|e| e.to_str()) != Some("rs") {
            continue;
        }

        let file = path
            .file_name()
            .and_then(|n| n.to_str())
            .expect("file name")
            .to_string();
        let text = fs::read_to_string(&path).expect("read source");
        let spans = guarded_spans(&text);

        for call in MUTATING_CALLS {
            for (at, _) in text.match_indices(call) {
                scanned += 1;

                if spans.iter().any(|(open, close)| at > *open && at < *close) {
                    continue;
                }

                let function = enclosing_fn(&text, at);
                if ALLOWED_OUTSIDE_GUARDED
                    .iter()
                    .any(|(f, fun)| *f == file && *fun == function)
                {
                    continue;
                }

                escapes.push(format!(
                    "{file}:{} in fn {function} — {call}",
                    line_of(&text, at)
                ));
            }
        }
    }

    assert!(
        scanned > 0,
        "the scan found no mutating calls at all, so it is proving nothing — \
         MUTATING_CALLS is probably out of date with src/jj.rs"
    );

    assert!(
        escapes.is_empty(),
        "these rewrite history without a backup, a confirmation or a restore point:\n  {}\n\
         wrap them in guard::guarded, or add them to ALLOWED_OUTSIDE_GUARDED with a reason",
        escapes.join("\n  ")
    );
}

#[test]
fn the_allowed_exceptions_still_exist() {
    let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("src/commands");

    for (file, function) in ALLOWED_OUTSIDE_GUARDED {
        let text = fs::read_to_string(dir.join(file)).expect("read source");
        assert!(
            text.contains(&format!("fn {function}")),
            "{file} has no fn {function} — a stale exception silently widens \
             what is allowed to bypass the guard"
        );
    }
}
