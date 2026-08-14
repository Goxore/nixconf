use crate::jj::Change;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Target {
    pub commit_id: String,
    pub change_id: String,
    pub description: String,
    pub undescribed_above: usize,
    pub insert_before: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NoTarget {
    EmptyLog,
    NoDescribed,
    NoEmptyAbove { tip: Change },
    Divergent { change: Change },
}

pub fn pick_target(ancestors: &[Change]) -> Result<Target, NoTarget> {
    if ancestors.is_empty() {
        return Err(NoTarget::EmptyLog);
    }

    let mut undescribed_above = 0usize;

    for change in ancestors {
        if change.divergent {
            return Err(NoTarget::Divergent {
                change: change.clone(),
            });
        }

        if !change.described {
            undescribed_above += 1;
            continue;
        }

        if undescribed_above == 0 {
            return Err(NoTarget::NoEmptyAbove {
                tip: change.clone(),
            });
        }

        return Ok(Target {
            commit_id: change.commit_id.clone(),
            change_id: change.change_id.clone(),
            description: change.description.clone(),
            undescribed_above,
            insert_before: ancestors[undescribed_above - 1].commit_id.clone(),
        });
    }

    Err(NoTarget::NoDescribed)
}
