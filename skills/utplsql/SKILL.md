---
name: utplsql
description: Writing, running and fixing utPLSQL v3 unit tests for an Oracle PL/SQL package - reading the package spec, choosing cases (happy path, boundaries, NULLs, expected exceptions), writing the test package with --%suite/--%test/--%context/--%beforeall/--%throws annotations, comparing cursors, running ut.run from SQL*Plus or SQLcl, reading the report and fixing failures without weakening assertions. Use when asked to add tests to a package, cover a bug with a test before fixing it, set up a CI test run, or explain a utPLSQL failure.
---

# utPLSQL tests for a PL/SQL package

**Measured on:** utPLSQL **v3.2.3** (`ut.version()` = `v.3.2.3.4508`) on
Oracle AI Database 26ai Free 23.26.1, SQL*Plus 23.26.1. Every behaviour and
message quoted below was reproduced there. A worked, passing example lives in
[`examples/`](examples/README.md).

## 0. Where tests may run

- **Dev or test schema only. Never production.** Tests insert, update and
  delete. If you cannot tell which database a connection points at, ask —
  do not run.
- **No DBA rights needed.** The test-owning schema needs `create session` and
  `create procedure` (plus whatever objects the code under test uses).
  utPLSQL itself is installed once, by whoever owns the database, with its
  headless installer; public synonyms make `ut`, `ut_runner` and the
  reporters visible to every schema.
- **Test data is never committed** — not to the database, not to the
  repository. Tests create the rows they need and utPLSQL rolls them back (§4).

## 1. Read the spec first

Test the contract, not the implementation. Before writing a test:

```sql
select text from user_source where name = 'PRICE_CALC' and type = 'PACKAGE' order by line;
select object_name, argument_name, position, data_type, in_out, defaulted
  from user_arguments where package_name = 'PRICE_CALC' order by object_name, position;
```

From each public subprogram, collect: its parameters and defaults, what it
returns or changes, the error codes and named exceptions in the spec, and the
tables it touches. Comments in the spec are the requirements; if a rule is
only in the body, ask whether it is intended before you pin it with a test.

## 2. Choose the cases

For every public subprogram, write down one line per case before any code:

| Kind | What to cover |
|---|---|
| Happy path | one typical input with a hand-computed expected value (show the arithmetic in a comment) |
| Boundaries | each threshold **and** the value either side of it (9 / 10 / 49 / 50) — off-by-one bugs live here |
| NULLs | each parameter NULL in turn; the spec says what should happen, or ask |
| Defaults | the call with defaulted parameters omitted |
| Errors | every documented error code / named exception, one test each |
| Data | rows changed (re-select them), rows filtered and ordered (cursor compare) |

The expected value comes from the spec or from arithmetic you can show — never
from running the code and copying what it returns. That only proves the code
does what it does.

## 3. The test package

A test suite is a normal package whose **spec** carries annotations. Name it
`test_<package>` and keep it in the same schema as the code under test (or a
schema granted `execute` on it).

```sql
create or replace package test_price_calc as
  --%suite(price_calc)
  --%suitepath(demo)

  --%context(tier_discount)

    --%test(Exactly 10 units gets 5 percent)
    procedure tier_at_10;

  --%endcontext

  --%test(Zero quantity raises -20001)
  --%throws(-20001)
  procedure total_zero_qty;

  --%test(Unknown SKU raises NO_DATA_FOUND)
  --%throws(no_data_found)
  procedure set_price_unknown_sku;

  --%test(Waiting for the rounding rule to be agreed)
  --%disabled(rounding rule not agreed yet)
  procedure total_bankers_rounding;
end test_price_calc;
/
```

| Annotation | Meaning |
|---|---|
| `--%suite(name)` | marks the package as a suite; **must be followed by a blank line** |
| `--%suitepath(a.b)` | groups suites into a tree for `ut.run(':a')` |
| `--%test(description)` | the next procedure is a test; the description is what the report shows |
| `--%context(name)` … `--%endcontext` | a nested group with its own before/after procedures |
| `--%beforeall` / `--%afterall` | run once per suite or context |
| `--%beforeeach` / `--%aftereach` | run around every test in the suite or context |
| `--%throws(...)` | test passes only if it raises one of these: `-20001`, `no_data_found`, `pkg.e_name`; several comma-separated |
| `--%disabled(reason)` | skipped and counted as disabled; always give the reason |
| `--%rollback(manual)` | turns automatic rollback off — only for code that must commit; then clean up yourself in `--%aftereach` |

**Measured trap:** with no blank line between `--%suite` and the first
`--%test`, the package is not recognised as a suite at all and `ut.run` fails
with `ORA-20204: Suite package utdemo.<name> does not exist`. The message
points at the wrong cause.

The body holds plain procedures with expectations:

```sql
ut.expect(price_calc.tier_discount(10)).to_equal(5);
ut.expect(price_calc.tier_discount(null)).to_be_null();
ut.expect(price_calc.is_bulk(50)).to_be_true();
ut.expect(price_calc.is_bulk(49)).to_be_false();
ut.expect(l_name, 'customer name after rename').to_equal('NEW NAME');  -- message shows on failure
```

Other matchers: `not_to_equal`, `to_be_not_null`, `to_be_greater_than`,
`to_be_less_than`, `to_be_between(a, b)`, `to_be_like('A-%')`,
`to_match('^A-\d+$')`, `to_have_count(n)` and `to_be_empty()` on cursors.

**Cursor comparison** checks rows, columns and order in one assertion:

```sql
open l_expected for
  select 'A-100' as sku, 4.00 as unit_price from dual union all
  select 'A-200',        12.50              from dual;
l_actual := price_calc.active_prices(p_max_price => 50);
ut.expect(l_actual).to_equal(l_expected);
```

Column names must match — alias the expected query; a wrong alias reports
`Column <B> [data-type: NUMBER] is missing`. Row order matters; on a
mismatch the report lists each differing row as XML. Add
`.join_by('SKU')` only when order is genuinely not part of the contract —
it makes the comparison order-insensitive.

**Expected exceptions:** the test body just makes the call. Do not wrap it in
`begin … exception when others` — that hides the failure. A `--%throws` test
whose code raises nothing fails with
`Expected one of exceptions (-20001) but nothing was raised.`

## 4. Data setup and rollback

utPLSQL sets a savepoint before each suite, context and test and rolls back
to it afterwards. So a `--%beforeall` that inserts rows, and tests that change
them, leave nothing behind — measured: the demo table had 0 rows after a run
that seeded 4 and updated one.

- **Own your data.** Start the setup by removing or isolating rows the tests
  depend on (`delete from price_list;` inside the rolled-back setup), so
  results do not depend on what else is in the dev schema.
- **No commits in code under test, no DDL in tests.** A commit breaks the
  rollback; the run reports
  `Unable to perform automatic rollback after test` as a warning and the data
  stays. If the code must commit, use `--%rollback(manual)` and delete what you
  created in `--%aftereach`.
- **Use synthetic values** (`A-100`, `TEST-%`) — never copy rows from a live
  system into a test.

## 5. Run and read the result

```sql
set serveroutput on size unlimited format wrapped
exec ut.run('test_price_calc');            -- one suite (prefix schema.: 'utdemo.test_price_calc')
exec ut.run('test_price_calc.tier_at_10'); -- one test
exec ut.run(':demo');                      -- everything under suitepath "demo"
begin ut.run(); end;                       -- every suite in the current schema
/
```

A suitepath needs the leading colon: `ut.run('demo')` is read as a schema
name and fails with `ORA-44001: invalid schema`. `format wrapped` keeps the report's indentation in SQL*Plus. The last line is
the verdict:

```
15 tests, 0 failed, 0 errored, 0 disabled, 0 warning(s)
```

- **failed** — an expectation was false. The report shows actual vs expected
  and the line of the `ut.expect`.
- **errored** — the test raised an exception it did not declare (in the
  failure list it still says `FAILED`, but the summary counts it as errored).
- **warning(s)** — usually a commit or rollback inside the tested code.

**`exec ut.run(...)` exits 0 even when tests fail.** For CI, call
`ut_runner.run` with `a_fail_on_errors => true` under
`whenever sqlerror exit failure`; it raises `ORA-20213: Some tests failed`.
[`examples/run_tests.sql`](examples/run_tests.sql) prints the report first and
then exits 1 — measured.

## 6. Fixing a failing test

1. Read the failure: actual, expected, line.
2. Decide which side is wrong **from the spec**, not from which is easier to
   change. In the example, `tier_discount(10)` returned 0; the spec says
   "5 from 10 to 49", so the code (`> 10`) was wrong, not the test.
3. Fix the code, recompile, check `user_errors`, re-run the whole suite.
4. If the test was wrong, fix it — and say why in the commit message.

Never "fix" a red test by: loosening `to_equal` to `to_be_not_null`, adding
`join_by` to make an order problem disappear, catching the exception in the
test, deleting the assertion, or marking it `--%disabled` without a reason and
an owner. A test with no `ut.expect` at all **passes** — measured — so an
emptied test is a silent lie.

## 7. Checklist

- [ ] Connected to a dev/test schema, confirmed — not production
- [ ] Every public subprogram has happy path, boundary, NULL and error cases
- [ ] Expected values come from the spec or shown arithmetic
- [ ] Blank line after `--%suite`; every test has a description
- [ ] Expected errors use `--%throws`, not exception handlers in the test
- [ ] Setup data is synthetic, created in `--%beforeall`/`--%beforeeach`, never committed
- [ ] Suite run shows `0 failed, 0 errored`; disabled tests have a reason
- [ ] CI uses `ut_runner.run(..., a_fail_on_errors => true)` so failures fail the job
