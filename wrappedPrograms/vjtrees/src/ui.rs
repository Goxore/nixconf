use anyhow::{Result, bail};
use indicatif::{ProgressBar, ProgressStyle};
use inquire::{Confirm, Password, PasswordDisplayMode, Select, Text};
use owo_colors::{OwoColorize, Stream::Stdout, Style};
use std::fmt::Display;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

fn styled(text: &str, style: Style) -> String {
    text.if_supports_color(Stdout, |t| t.style(style))
        .to_string()
}

pub fn bold(text: &str) -> String {
    styled(text, Style::new().bold())
}

pub fn dim(text: &str) -> String {
    styled(text, Style::new().dimmed())
}

pub fn red(text: &str) -> String {
    styled(text, Style::new().bright_red().bold())
}

pub fn green(text: &str) -> String {
    styled(text, Style::new().bright_green().bold())
}

pub fn yellow(text: &str) -> String {
    styled(text, Style::new().bright_yellow().bold())
}

pub fn cyan(text: &str) -> String {
    styled(text, Style::new().bright_cyan().bold())
}

pub fn magenta(text: &str) -> String {
    styled(text, Style::new().bright_magenta().bold())
}

pub fn heading(text: &str) -> String {
    magenta(text)
}

pub fn rule() -> String {
    dim(&"─".repeat(58))
}

static ASSUME_YES: AtomicBool = AtomicBool::new(false);

pub fn assume_yes(yes: bool) {
    ASSUME_YES.store(yes, Ordering::Relaxed);
}

fn assuming_yes() -> bool {
    ASSUME_YES.load(Ordering::Relaxed)
}

pub fn confirm(question: &str, default_yes: bool) -> Result<bool> {
    if assuming_yes() {
        println!("  {question} {}", dim("[--yes]"));
        return Ok(true);
    }

    match Confirm::new(question).with_default(default_yes).prompt() {
        Ok(answer) => Ok(answer),
        Err(inquire::InquireError::OperationCanceled)
        | Err(inquire::InquireError::OperationInterrupted) => Ok(false),
        Err(e) => bail!("cannot ask for confirmation: {e}"),
    }
}

pub fn confirm_typed(question: &str, expected: &str) -> Result<bool> {
    let expected = expected.to_string();
    let wanted = expected.clone();

    let answer = Text::new(question)
        .with_help_message(&format!(
            "type {expected} to confirm — this cannot be undone"
        ))
        .with_validator(move |input: &str| {
            if input == wanted {
                Ok(inquire::validator::Validation::Valid)
            } else {
                Ok(inquire::validator::Validation::Invalid(
                    format!("type {wanted} exactly, or press Esc to abort").into(),
                ))
            }
        })
        .prompt();

    match answer {
        Ok(text) => Ok(text == expected),
        Err(inquire::InquireError::OperationCanceled)
        | Err(inquire::InquireError::OperationInterrupted) => Ok(false),
        Err(e) => bail!("cannot ask for confirmation: {e}"),
    }
}

pub fn ask(question: &str) -> Result<String> {
    match Text::new(question).prompt() {
        Ok(text) => Ok(text.trim().to_string()),
        Err(e) => bail!("cannot read input: {e}"),
    }
}

pub fn ask_secret(question: &str) -> Result<String> {
    match Password::new(question)
        .with_display_mode(PasswordDisplayMode::Masked)
        .without_confirmation()
        .prompt()
    {
        Ok(text) => Ok(text.trim().to_string()),
        Err(e) => bail!("cannot read input: {e}"),
    }
}

pub fn select<T: Display>(question: &str, options: Vec<T>) -> Result<Option<T>> {
    if options.is_empty() {
        bail!("nothing to choose from");
    }

    match Select::new(question, options).with_page_size(15).prompt() {
        Ok(choice) => Ok(Some(choice)),
        Err(inquire::InquireError::OperationCanceled)
        | Err(inquire::InquireError::OperationInterrupted) => Ok(None),
        Err(e) => bail!("cannot show the picker: {e}"),
    }
}

pub fn multi_select<T: Display>(question: &str, options: Vec<T>) -> Result<Vec<T>> {
    if options.is_empty() {
        return Ok(Vec::new());
    }

    match inquire::MultiSelect::new(question, options)
        .with_page_size(15)
        .prompt()
    {
        Ok(chosen) => Ok(chosen),
        Err(inquire::InquireError::OperationCanceled)
        | Err(inquire::InquireError::OperationInterrupted) => Ok(Vec::new()),
        Err(e) => bail!("cannot show the picker: {e}"),
    }
}

pub struct Choice<T> {
    pub label: String,
    pub value: T,
}

impl<T> Choice<T> {
    pub fn new(label: impl Into<String>, value: T) -> Self {
        Self {
            label: label.into(),
            value,
        }
    }
}

impl<T> Display for Choice<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.label)
    }
}

pub struct Spinner(Option<ProgressBar>);

pub fn spinner(message: &str) -> Spinner {
    if assuming_yes() || !std::io::IsTerminal::is_terminal(&std::io::stdout()) {
        println!("  {message}...");
        return Spinner(None);
    }

    let bar = ProgressBar::new_spinner();
    bar.set_style(
        ProgressStyle::with_template("  {spinner:.cyan} {msg}")
            .unwrap_or_else(|_| ProgressStyle::default_spinner()),
    );
    bar.set_message(message.to_string());
    bar.enable_steady_tick(Duration::from_millis(80));

    Spinner(Some(bar))
}

impl Spinner {
    pub fn finish(self, message: &str) {
        if let Some(bar) = self.0 {
            bar.finish_and_clear();
        }
        println!("  {message}");
    }

    pub fn clear(self) {
        if let Some(bar) = self.0 {
            bar.finish_and_clear();
        }
    }
}
