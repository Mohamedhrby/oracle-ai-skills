# Oracle AI Skills (free starter set)

Four skills that make an AI coding assistant better at Oracle work — written
as a senior Oracle developer would brief a new team member, and tested where
they could be run.

| Skill | Gives your assistant |
|---|---|
| [`oracle-apex`](skills/oracle-apex/SKILL.md) | Page patterns, region choice, the slot contract, accessibility non-negotiables, the traps that cost the most time, and a done-checklist (APEX 26.1) |
| [`plsql`](skills/plsql/SKILL.md) | Schema-first generation, package structure, error handling that does not hide failures, autonomous audit, concurrency, bulk — traps measured on Oracle AI Database 26ai |
| [`forms-to-apex`](skills/forms-to-apex/SKILL.md) | Source extraction, inventory, trigger→APEX mapping, moving logic into packages, parity testing, risk sequencing |
| [`utplsql`](skills/utplsql/SKILL.md) | utPLSQL v3 tests for a PL/SQL package: choosing cases from the spec, annotations, cursor comparison, safe data setup, CI runs that fail on red, and fixing failures without weakening assertions — with a [worked example](skills/utplsql/examples/README.md) recorded red → green on Oracle AI Database 26ai |

They use Anthropic's Agent Skills format and plain Markdown, so they work in
Claude Code and Claude.ai, and as knowledge files in ChatGPT, Gemini, Copilot,
Cursor or a local model.

## Install (Claude Code)

```bash
git clone https://github.com/Mohamedhrby/oracle-ai-skills
cp -r oracle-ai-skills/skills/* ~/.claude/skills/
```

Other assistants: upload each `SKILL.md` as a knowledge file and tell the
assistant to follow the matching skill for Oracle questions.

## Want the full set?

The [Premium Skills Pack](https://harby.dev/skills) adds six more skills —
SQLcl + Liquibase deployments, ORDS REST, APEX Template Components and
pixel-faithful UI, Oracle DB AI, APEX AI, and a safe Claude Code setup for
Oracle projects — plus the APEX skill's eight measured reference files and
tested example scripts.

## License

MIT © Mohamed Harby — see [LICENSE](LICENSE). Built for
[harby.dev](https://harby.dev). Oracle and APEX are trademarks of Oracle;
this project is independent and not endorsed by Oracle.
