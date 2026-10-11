---
name: forms-to-apex
description: Migrating Oracle Forms applications to Oracle APEX - extracting FMB/MMB/OLB/PLL source with frmf2xml and the Forms compiler, building a structured inventory with an AI agent, mapping blocks, triggers, LOVs and canvases to APEX components, moving logic into database packages, rating risk, and proving parity with the legacy screens. Use when assessing a Forms estate, reverse-engineering a module, planning or sequencing a migration, deciding where a trigger's logic should live in APEX, or testing that a migrated page behaves like the form it replaces.
---

# Oracle Forms → APEX

**Checked against:** Oracle Forms 12.2.1.4 and APEX 26.1/26.2 documentation
(reviewed October 2026). APEX's old built-in Forms "Migration Project" was
desupported in **APEX 21.1** — current releases have no Forms importer, so the
inventory and blueprint below *are* the migration tooling.

**The goal is the same behaviour, not the same screens.** A migrated page is
done when it enforces the same rules on the same inputs and produces the same
data — proven (§5), not asserted.

## 1. Get the source into text

| Source | Tool | Output |
|---|---|---|
| Form `.fmb`, menu `.mmb`, object library `.olb` | `frmf2xml.sh OVERWRITE=YES ORDERS.fmb` | `ORDERS_fmb.xml` |
| Same, every property incl. inherited (analysis only) | `frmf2xml.sh OVERWRITE=YES DUMP=ALL ORDERS.fmb` | richer XML that cannot be converted back |
| PL/SQL library `.pll` | `frmcmp_batch.sh module=LIB.pll module_type=library logon=no script=yes output_file=LIB.pld` | `LIB.pld` text |

- The `.fmx` is a compiled runtime file — not an input. No source, no migration;
  find the `.fmb`.
- Trigger and program-unit code sits in XML attributes (`TriggerText`,
  `ProgramUnitText`) with newlines escaped as `&#10;` — decode before reading.
- "Error initialising the Forms Jdapi" on a headless server usually means no X
  display: point `DISPLAY` at an X server (Xvfb).
- Form source contains table names, rules and sometimes credentials. Check
  your policy before sending it to an external AI service; a local model
  (see the `apex-ai` skill) keeps it in-house.

## 2. Inventory — one module at a time

Have the agent produce **tables, not prose**, per module:

- blocks (base table or query, where-clause, order-by, master-detail relations)
- items (type, data type, required, default, LOV, validation)
- triggers, with level (form / block / item), event, and the PL/SQL
- program units and attached-library calls
- LOVs and record groups (their SQL)
- canvases, windows, tab pages; menus and their roles
- global variables and parameters, and who sets / reads them
- every `CALL_FORM` / `OPEN_FORM` / `NEW_FORM` — the navigation graph

Then **verify against the running form**: open it, exercise each trigger the
inventory claims. An inventory nobody checked is a guess with a table around it.

## 3. Map to APEX

| Forms | APEX |
|---|---|
| Single-table data block | Form region (one record) · Interactive Grid (editable many) · Interactive Report (read many) |
| Master-detail blocks | Master-detail: form + IG, or IG + IG |
| LOV / record group | Shared LOV; Popup LOV item |
| `WHEN-NEW-FORM-INSTANCE` | Page process *Before Header*, or computations |
| `POST-QUERY` (lookup descriptions) | Join or scalar subquery **in the region's query** |
| `WHEN-VALIDATE-ITEM` / `-RECORD` | Validations (item / page); rule in a package function |
| `PRE-INSERT` / `PRE-UPDATE` (keys, audit columns) | Identity column / default / DB trigger or the DML package |
| `ON-INSERT` / `ON-UPDATE` / `KEY-COMMIT` | Page process calling the package; IG *Interactive Grid – Automatic Row Processing* or custom PL/SQL |
| `WHEN-BUTTON-PRESSED` | Button + process, or Dynamic Action |
| `WHEN-LIST-CHANGED`, item-level UI logic | Dynamic Action (cascading LOV: *Parent Item*) |
| Stacked / tab canvases, multiple windows | Regions, tabs (Region Display Selector), modal dialog pages, drawers |
| Global variables | Application items (session state protected) |
| `CALL_FORM` / `OPEN_FORM` | Page navigation, modal dialog with return items |
| Menu + role checks | Navigation menu + **Authorization Schemes** |
| User exits (C / Pro*C) | Rewrite: PL/SQL, an external service, or drop |

## 4. Move the logic into the database — first

Before building pages, lift business rules out of triggers into **PL/SQL
packages** in the schema: validations become functions, DML becomes an API.
Then APEX calls the same code the rules live in, the rules are testable
without either UI, and — during a phased migration — the remaining Forms can
call the same packages, so both front ends enforce one set of rules.

Logic that is purely UI (enable/disable, show/hide, navigation) stays in APEX
as Dynamic Actions and conditions.

## 5. Prove parity

For each migrated module, a parity list, rule by rule:

| Rule (from the inventory) | Input | Forms result | APEX result |
|---|---|---|---|
| Discount > 20% needs manager | 25%, clerk | blocked, message X | blocked, message X |

- Same inputs in both systems; compare **messages, saved data and side
  effects** (audit rows, emails), not just "it saved".
- Include the unhappy paths — the validation that fires, the record that is
  locked, the duplicate that is refused.
- Track it as a count: *37 of 40 rules matched* tells a sponsor where the
  project is; "nearly done" does not.

## 6. Blueprint and sequencing

The blueprint is the inventory plus, per object: proposed APEX component,
what has no direct equivalent, and a risk rating with a one-line mitigation.
Name the target APEX release in the prompt so the agent proposes only
components that exist in it.

- **Low**: single-table blocks, simple LOVs.
- **Medium**: complex triggers, master-detail, multi-block coordination.
- **High**: multiple windows and stacked canvases, `KEY-` triggers, user exits,
  long validation chains.

**Migrate by risk, not by menu order**: ship low-risk modules first, move
shared logic into packages early, and take high-risk modules once the patterns
are proven.

## 7. Checklist

- [ ] Source (`.fmb`/`.mmb`/`.olb`/`.pll`) found and converted for every module
- [ ] Inventory per module, verified against the running form
- [ ] Every object mapped; gaps listed with a decision
- [ ] Business rules moved into packages before pages are built
- [ ] Parity list per module, including unhappy paths, with a matched count
- [ ] Authorization schemes replace menu role checks
- [ ] Sequenced by risk; target APEX release named in every generation prompt
