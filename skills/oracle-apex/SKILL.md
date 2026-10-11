---
name: oracle-apex
description: Building or reviewing Oracle APEX applications - pages, regions, Universal Theme, Template Components, APEXlang exports, interactive grids, calendars, charts, faceted search, workflow/approvals/tasks, JSON duality views, accessibility, RTL and multi-language. Use when writing .apx files, choosing a region type, styling with Universal Theme, designing a dashboard or list page, wiring a workflow or human task, or debugging an APEX page that renders wrongly.
---

# Oracle APEX, done properly

## Provenance — read this before trusting a line of it

| | |
|---|---|
| **Measured on** | Oracle APEX **26.1** · ORDS 26.1 · Oracle Database 23ai Free · Universal Theme 42 |
| **Corpus** | **all 701 pages** of 16 applications — Oracle's sample and reference apps plus one multi-tenant SaaS app: `customers` 127, `ut` (Universal Theme Reference) 122, `team-calendar` 51, `sample-interactive-grids` 49, `sample-charts` 49, `brookstrut` 48, `qask` 42, `sample-calendar` 37, `sample-workflow-approvals` 34, `sample-master-detail` 34, a multi-tenant SaaS starter 34, `ux-pattern-catalog` 26, `sample-cards` 25, `json-duality-views` 12, `image-support-rte` 7, `sample-docgen` 4 |
| **Method** | each app exported with `apex export -expType APEXLANG -split` and parsed; every construct counted; then each application driven in a browser — signed in, pages walked, records created, a salary-change approval run end to end and the base table checked, an appraisal workflow started and advanced through a human task |
| **Read** | 2026-09-22 (earlier pass on the UX Pattern Catalog: 2026-09-15) |
| **Second source** | defects measured on a real production multi-tenant build (APEX 26.1 + ORDS 26.1.2 + Oracle AI Database 26ai Free) |

**Every claim here is measured, not inferred.** Counts are facts about this
corpus and this release. When APEX moves past 26.1, re-measure.

**Where to install it.** `~/.claude/skills/oracle-apex/` applies to every
project; `.claude/skills/oracle-apex/` inside a repository pins it to that
project's APEX release. When both exist, the repository copy wins.

---

## The reference files

This free edition is the core skill. The eight measured reference files it
mentions (`reference/apexlang.md`, `universal-theme.md`, `patterns.md`,
`interactive-grid.md`, `workflow-tasks.md`, `data-sources.md`, `traps.md`)
and the `apex-template-components` skill are part of the
[Premium Skills Pack](https://harby.dev/skills). Without them, follow the
rules below and check details against Oracle's APEX documentation.

---|---|
| `reference/apexlang.md` | writing or reading any `.apx` — the full measured grammar, every object kind, every vocabulary, and what the export does **not** carry |
| `reference/universal-theme.md` | choosing a template, a template option or a CSS class; theming; template directives; UT JavaScript |
| `reference/patterns.md` | deciding what a **page** should be — dashboards, browse/search, item detail, selection, data entry, master-detail, cards. Oracle's own written doctrine |
| the `apex-template-components` skill | writing or designing a Template Component region — the eight built-in components with exact APEXlang, slots and plugin keys, custom components, and the pixel-faithful build loop |
| `reference/interactive-grid.md` | anything editable, frozen, virtual-scrolled, or master-detail in a grid |
| `reference/workflow-tasks.md` | human tasks, approvals, workflows — including why a workflow silently does nothing |
| `reference/data-sources.md` | calendars, charts, JSON duality views, document generation, cards mechanics, faceted/smart filters |
| `reference/traps.md` | whenever something does not work and there is no error message. Two halves: traps from the sample applications, then traps measured on a production build — plug-in regions, the importer's refused property forms, CRLF, SVG, and which bidi shapes actually reverse in Arabic |
| Oracle's Blueprint prompt | generating an application or module with an **APEX Blueprint**. Fetch Oracle's own system prompt and icon allowlist from [oracle/apex › blueprints/prompt](https://github.com/oracle/apex/tree/26.1/blueprints/prompt) at the branch matching your APEX release, and load them whole into the generating model; never paraphrase or trim them |

---

## 1. Choose the page pattern, then the region type

**First** decide what the page is for — `reference/patterns.md` §1 has the nine
patterns Oracle documents and when each applies. **Then** pick regions:

| The user's job | Region type | Not |
|---|---|---|
| Scan records, act on one | `themeTemplateComponent/contentRow` | a classic report with markup in the SELECT |
| A few headline numbers | `themeTemplateComponent/metricCard` | hand-built cards, and never a report of label/value rows |
| Browse a large set with filters | `facetedSearch` + `cards` or `contentRow` | a search box and a report |
| The same, but the filter should read as a search bar | `smartFilters` in the breadcrumb's `searchFieldAndSmartFilters` slot | a row of select lists |
| Compare many rows, sort, save views | `interactiveReport` | a contentRow with 200 rows |
| Edit in place, freeze columns, scroll 100k rows | `interactiveGrid` | an IR plus a form page per row |
| One record, full detail | header + `t-AVPList` + section regions | a form in display-only mode |
| Pick from a list, see detail beside it | `@/left-side-column` + `rowSelection` on the list + `.js-item-refresh` on the detail regions | a two-pane layout hand-built in CSS |
| Create or edit | `form` region | hand-written items and a process |
| A short edit without leaving the page | `pageMode: modalDialog` + `dialogTemplate: @/drawer` | a full page |
| Events in time | `calendar` | a report sorted by date |
| A shape of change over time | `chart` with one series | three series and a legend |
| A status, a count, a person | `badge` / `avatar` template components | a `<span>` with inline style |
| A JSON document with nested arrays | `jsonDualityView` source + `dataProfile { nestedRows }` | a view per level |

**If you are about to write `sys.htp.p` to build a row, a card or a badge, stop.**
A Template Component renders it, with keyboard behaviour, pagination, grouping
and RTL mirroring you would otherwise owe.

## 2. The slot contract — and the read-side rule it enforces

Every value a Template Component renders comes from a **column of one query**,
mapped in `settings { }` or a `plugin-*` block:

```
settings      { overline: &OVERLINE.  title: &TITLE.  miscellaneous: &MISC. }
plugin-avatar { type: initials  initials: INITIALS  shape: circular }
plugin-badge  { value: BADGE  state: BADGE_STATE  style: subtle }
```

There is no expression slot, so a per-row PL/SQL call has nowhere to go. The
read-side rule stops being something people remember and becomes something the
component cannot break: **the query returns it, the page never calls a function
per row.**

The whole corpus obeys this. The workflow sample's employee cards compute
`PENDING_SALARY_APPROVAL`, `IS_DIRECT_OR_INDIRECT_REP` and friends in the
region's SQL, and each card action carries a `serverSideCondition` on one of
those **columns**. Raising a request makes the matching action vanish on the next
refresh — verified in the running app.

**Markup is allowed in the slot; the substituted value is what gets escaped.**
Write the HTML and the directives in the slot, and escape each value on its way
in — `&NAME!HTML.` in text, `&URL!ATTR.` in an `href`. `reference/traps.md`
has the measurement, including the correction to an earlier, over-broad claim.

## 3. Non-negotiables

**Never take Oracle's semantic colours.** Measured: `t-Badge--info` is **3.12:1**
and `t-Badge--warning` **2.56:1** at 13px in the subtle style these components
render — both below WCAG 2.2 AA, both reported *serious* by axe-core. Adopt the
**markup**, repaint the four states from your own measured tokens, scoped to a
class the region opts into. Same for `t-Avatar`'s `u-color-1..45`: never
contrast-checked.

**Badge value, state and icon must mean the same thing.** Oracle's own rule, and
the one that makes a status list readable: success = positive completion,
warning = incomplete or pending, danger = blocker or action required, info =
neutral context. And never colour alone.

**Decorative discs are `aria-hidden`; the name is text.** Oracle's own markup
does this — the avatar is `aria-hidden="true"`, the name is an `<h3>` with a
link, the badge carries `role="status"` with an accessible name that spells the
state out. Copy that exactly. Icon-only controls get `u-VisuallyHidden` text.

**Logical properties only.** `u-textStart`, `margin-inline-start`, `inline-size`.
A physical `right` is a page that breaks in Arabic and nobody on an
English-speaking team will look. Oracle's own sample CSS is written this way.

**Heading level is document structure, not type size.** `t-ContentBlock--h2`
sets the level; `u-text-heading-lg` sets the size. Use `js-headingLevel-N` to
keep the outline right on regions that do not take a content block.

**Scope page CSS to the pattern.** A class on the region named for the pattern
(`app-MetricCards`), every selector prefixed with it, and the class names the
pattern rather than the tweak. Style against the `--ut-*` CSS variables, never
hard-coded colours, or Theme Roller and every theme style pass you by.

**Document intent in metadata, not on the page.** Every region gets a
`comments { }` block — *Intent / Pattern role / AI guidance*, or *## Purpose /
## When to Use / ## When to Avoid / ## AI Guidance* — and every page a
`help { helpText }`. This is Oracle's own convention across the catalogue and it
is where the next reader actually looks.

## 4. The traps that cost the most time

Full list with error text in `reference/traps.md`. The ones that bite first:

1. **A `/* … */` comment between properties in an `.apx` does not survive the
   round trip.** Commentary goes inside a fenced block, a `comments { }`, or
   `help { helpText }`. The exporter also reorders columns and processes: write,
   export, **adopt what comes back**.
2. **Page 0 has total blast radius.** A region or item on the global page that
   raises replaces *every page* with an error page for every signed-in user.
   Make page-0 components fail closed to *nothing*, never to an error.
3. **A deep link without `session=` starts a new session.** Rejoin is off by
   default, so a bookmarked or scripted URL lands on Sign In — measured across
   five apps. Navigate through the UI or carry the session id.
4. **A modal-dialog page opened as an ordinary page throws.** It is reachable
   only through a dialog-opening action.
5. **A button with no `action:` key is a Submit Page button** — 376 of 1240 in
   the corpus. `databaseAction: insert|update|delete` marks the DML ones.
6. **Workflows arrive inert.** The APEXlang export carries no version state, so
   every import lands in *Development* and the first symptom is a user pressing
   a button. Activation is a post-deployment step, sub-workflows first, and a
   version needs an Owner participant.
7. **The workflow engine is scheduler-driven and silent.** An instance can sit
   *Active* with zero activities and no error anywhere if
   `job_queue_processes` is starved.
8. **`flexboxContainer` children must go in `slot: plugin-body`.** Put them in
   `subRegions` and they vanish silently — the component has no such slot. (An
   earlier version of this skill blamed the component; it was the slot.)
9. **`apex_util.set_session_lang` does not affect the request it is called in.**
   It needs a process at *On Load: Before Header* plus a redirect.
10. **The APEXlang transpiler NPEs** on a redirect target's `items`/`value`
    array — on a report column's link **and** on a button's. Build the URL with
    `apex_page.get_url` into an item and point `targetUrl` at it.
11. **An LOV query must not begin with a `--` comment.** The page dies with
    "Error during rendering of page item X" and nothing else.
12. **Display Image with `basedOn: blobColSql` returns ONE column.** On page 0
    it fails outright — use an Ajax Callback application process.

## 5. Workflow

```
author .apx  ->  apex import  ->  apex export -split -exptype APEXLANG  ->  diff
```

**Byte-identical is the standard.** When the diff differs, adopt the export.

Then verify **in a browser**, because the file gates cannot see:

- every design token resolves (`getComputedStyle` on `:root` — an empty value
  means the stylesheet is not loaded, which can be true for releases);
- axe-core, no serious or critical, **in light, dark and RTL**;
- every list page renders at least one row *and* its empty-state message is
  absent — APEX renders "no data found" as a row of the same table;
- anything asynchronous (workflows, emails, jobs) actually **moved**, not just
  got created.

And take the screenshot and **judge it**. "It rendered" is not the bar; "would
someone pay for this" is. The first attempt is usually mediocre — budget for the
second.

## 6. Checklist before calling a page done

- [ ] Page pattern chosen from `reference/patterns.md`, not defaulted
- [ ] Region type chosen from §1, not defaulted to a classic report
- [ ] No `*_api` or per-row function call in any `sqlQuery`; conditions read columns
- [ ] No `t-Badge--success|warning|danger|info`; own palette, measured
- [ ] Badge value / state / icon semantically aligned; never colour alone
- [ ] Decorative graphics `aria-hidden`, names as text, badges `role="status"`
- [ ] Heading levels form a correct outline
- [ ] Empty state written, and seen
- [ ] `comments { }` on every region, `help { helpText }` on the page
- [ ] Page CSS scoped to a pattern class; colours from `--ut-*` variables
- [ ] Round trip byte-identical
- [ ] axe clean in light, dark and RTL; tokens resolve; lists have rows
- [ ] If it has a workflow: version **Active**, sub-workflows first, Owner set,
      and an instance observed advancing
