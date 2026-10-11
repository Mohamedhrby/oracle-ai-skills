---
name: plsql
description: Writing and refactoring Oracle SQL and PL/SQL that is correct against the real schema - reading the data dictionary before generating code, package structure, error handling that does not hide failures, autonomous audit logging, bulk processing, concurrency, and the compile errors whose messages point the wrong way. Use when generating SQL or PL/SQL for an existing schema, reviewing a package, fixing PLS-/ORA- compile errors, or making a procedure safe under concurrent use.
---

# PL/SQL that matches the real schema

**Measured on:** Oracle AI Database 26ai Free 23.26.3. Every error text below
was reproduced there.

## 1. Read the schema before writing a line

Generated SQL is wrong mostly in one way: it invents a column, a type or a
relationship. Query the dictionary first and write against what it returns:

```sql
-- columns, types, nullability
select column_name, data_type, data_length, nullable
  from user_tab_columns where table_name = 'ORDERS' order by column_id;
-- keys and relationships
select c.constraint_name, c.constraint_type, cc.column_name, r.table_name ref_table
  from user_constraints c
  join user_cons_columns cc on cc.constraint_name = c.constraint_name
  left join user_constraints r on r.constraint_name = c.r_constraint_name
 where c.table_name = 'ORDERS';
-- what a package already offers (reuse before writing)
select object_name, procedure_name from user_procedures where object_name like 'ORDER%';
-- meaning
select column_name, comments from user_col_comments where table_name = 'ORDERS';
```

Done when every table, column and type in your code appears in that output.
Use `%TYPE` / `%ROWTYPE` for anything that mirrors a column, so a type change
is a recompile, not a bug.

## 2. Structure

- **Packages, not standalone procedures.** Spec = the contract; body = the
  implementation. Keep the spec small and stable: everything else in the
  database recompiles when it changes.
- **Declarations first.** Every type, constant and variable comes before the
  first subprogram body in a package body. A constant added next to the
  function that uses it fails with
  `PLS-00103: Encountered the symbol "C_FACTOR" when expecting one of the following: begin end function pragma procedure`
  — the message names the symbol, not the rule.
- **A package-private function cannot be called from SQL.**
  `select double_it(21) into l from dual` inside the body gives
  `PLS-00231: function 'DOUBLE_IT' may not be used in SQL`. Assign it to a
  local first (`l := double_it(21);`), or publish it in the spec.
- **`SQLERRM`, `SQLCODE` and collection methods (`.count`) are not SQL.**
  `insert into audit_log values (sqlerrm)` fails with
  `ORA-00984: column not allowed here`. Copy into a local, then insert the local.

## 3. Errors that tell the truth

- **Never `when others then null`.** It turns every failure — including the
  ones you did not imagine — into silent success. Catch what you can handle by
  name (`no_data_found`, `dup_val_on_index`); let the rest raise.
- **Log failures autonomously.** A failure-path log written in the caller's
  transaction is rolled back with it. Measured: after a `dup_val_on_index` and
  a rollback, the same-transaction audit row was gone and only the
  `pragma autonomous_transaction` row remained. Audit, security events and
  "who was denied" belong in an autonomous logger; business data never does.
- **Re-raise with context**: `raise_application_error(-20001, 'Order ' || p_id
  || ' cannot ship: ' || l_reason, true)` — the third argument keeps the
  original error stack.
- **Errors for humans vs machines.** Codes in the `-20000…-20999` range, one
  per business rule, documented in the spec; the message is for the user, the
  code is for the caller.

## 4. Correct under concurrency

- **Check-then-act is a race.** "Count, then insert if under the limit" lets
  two sessions both pass. Lock the row that represents the limit first:
  `select … from quotas where account_id = p_id for update;` then count and
  insert. The second session waits instead of overshooting.
- **Idempotency by constraint.** A unique key on the natural identity
  (`provider, event_id`) makes a retried request a `dup_val_on_index` you can
  treat as "already done", not a duplicate row.
- **Commit belongs to the caller.** Library procedures do not commit; the
  transaction boundary is the API or job that started the work.

## 5. Performance by default

- **Set-based first.** One `insert … select` or `merge` beats a loop of single
  rows every time it is possible.
- **When you must loop: bulk.** `bulk collect … limit 1000` in, `forall` out,
  with `save exceptions` when partial success is acceptable.
- **Binds, always.** Dynamic SQL uses `using :bind`, never concatenated values
  — for plan reuse and because concatenation is SQL injection. Identifiers
  that must be dynamic go through `dbms_assert.enquote_name` /
  `simple_sql_name`.
- **No per-row function calls in report queries** that the optimizer cannot
  see through; compute in the query, or use `result_cache` deliberately.

## 6. Scripts that fail loudly

Every deploy or test script starts with:

```sql
whenever sqlerror exit failure
whenever oserror exit failure
set define off          -- '&' in a string literal is otherwise a substitution prompt
```

A script without `whenever sqlerror` reports success after an error. And
after compiling, check `user_errors` / `user_objects where status = 'INVALID'`
— `create or replace` with compilation errors is a warning, not a failure.

## 7. Checklist

- [ ] Every table/column/type taken from the dictionary; `%TYPE` where it mirrors a column
- [ ] Declarations before subprogram bodies; nothing private called from SQL
- [ ] No `when others then null`; failure-path logging is autonomous
- [ ] Limits enforced with `for update`; idempotency by unique key
- [ ] Set-based where possible; bulk + binds otherwise
- [ ] Scripts `whenever sqlerror exit failure`; zero INVALID objects after compile
