# AgentiveStack bundle — origin & rename map

Copied from https://github.com/AgentiveStack/skills at commit
`69375219cb690f048c209eada0db272fb6450173` (2026-04-29).

This is a **fork-by-copy**, not a submodule. Upstream changes will not flow in
automatically. The skills here are expected to drift as they're amended to
match Panoply conventions; that's fine. License preserved (MIT, see `LICENSE`).

## Skill renames applied

To avoid name collisions with `core/` and to match Panoply's gerund-style
naming, every skill was renamed:

| Upstream | Local |
|---|---|
| `spec` | `writing-specs` |
| `domain` | `domain-modelling` |
| `slice` | `slicing-features` |
| `tdd` | `tracer-tdd` |
| `holistic` | `mapping-system` |
| `architect` | `architecting` |
| `qa` | `filing-bugs` |

Cross-references between skills (e.g. `/spec → /domain → /slice → /tdd`) were
rewritten to use the new names. Each skill's `name:` frontmatter was updated
to match its new directory.
