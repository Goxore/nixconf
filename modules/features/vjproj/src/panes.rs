use crate::tmux::Pane;

pub fn chain(pid: u32) -> Vec<u32> {
    let mut chain = vec![pid];
    chain.extend(crate::agents::ancestry(pid));
    chain
}

pub fn owner<'a>(chain: &[u32], panes: &'a [Pane]) -> Option<&'a Pane> {
    chain
        .iter()
        .find_map(|pid| panes.iter().find(|pane| pane.pid == *pid))
}
