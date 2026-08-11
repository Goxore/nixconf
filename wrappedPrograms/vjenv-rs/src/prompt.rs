use std::fs::File;
use std::io::{BufRead, BufReader, IsTerminal, Write};

pub fn pick<'a>(prompt: &str, options: &[&'a str]) -> Option<&'a str> {
    match options {
        [] => return None,
        [only] => return Some(only),
        _ => {}
    }
    let mut tty = terminal()?;

    eprintln!();
    eprintln!("  {prompt}");
    for (i, o) in options.iter().enumerate() {
        eprintln!("    {}) {o}", i + 1);
    }

    loop {
        eprint!("  choice: ");
        let _ = std::io::stderr().flush();
        let mut line = String::new();
        if tty.read_line(&mut line).ok()? == 0 {
            return None;
        }
        match line.trim().parse::<usize>() {
            Ok(n) if (1..=options.len()).contains(&n) => return Some(options[n - 1]),
            _ => eprintln!("  not one of the options"),
        }
    }
}

fn terminal() -> Option<Box<dyn BufRead>> {
    if std::io::stdin().is_terminal() {
        return Some(Box::new(BufReader::new(std::io::stdin())));
    }
    let tty = File::open("/dev/tty").ok()?;
    tty.is_terminal().then(|| Box::new(BufReader::new(tty)) as Box<dyn BufRead>)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_single_option_needs_no_terminal() {
        assert_eq!(pick("which?", &["only"]), Some("only"));
    }

    #[test]
    fn no_options_means_no_answer() {
        assert_eq!(pick("which?", &[]), None);
    }
}
