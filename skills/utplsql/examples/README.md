# utPLSQL example: `price_calc`

A small, synthetic pricing package and its utPLSQL test suite. No real data.

| File | What it is |
|---|---|
| `src/price_list.sql` | demo table the package reads and updates |
| `src/price_calc.pks` / `.pkb` | the package under test: tier discount, line total, bulk flag, price update, price list cursor |
| `test/test_price_calc.pks` / `.pkb` | the suite: 15 tests in 4 contexts — boundaries, NULLs, `--%throws` by code, by name and by package exception, `--%beforeall` data seed, cursor comparison |
| `install.sql` | creates everything in the current schema and fails if any object is invalid |
| `run_tests.sql` | runs the suite, prints the report, exits 1 if anything failed or errored |

## Run it

In a **dev/test schema** where utPLSQL v3 is installed (the schema needs
`create session`, `create table`, `create procedure` and a tablespace quota):

```bash
cd skills/utplsql/examples
sqlplus -S user/password@//host:1521/service @install.sql
sqlplus -S user/password@//host:1521/service @run_tests.sql
```

## Recorded runs

| | |
|---|---|
| Date | 2026-11-17 |
| Database | Oracle AI Database 26ai Free Release 23.26.1.0.0 (PDB `FREEPDB1`, throwaway Docker container) |
| utPLSQL | v3.2.3 (`select ut.version() from dual` → `v.3.2.3.4508`), installed with `source/install_headless.sql` from the official release archive |
| Client | SQL*Plus 23.26.1.0.0 |
| Schema | a dedicated empty test schema with the grants above, no DBA role |

### 1. Red — the suite catches a boundary bug

The first version of `tier_discount` used `elsif p_qty > 10`, so exactly
10 units got no discount, while the spec says "5 from 10 to 49". Two tests
caught it: the direct boundary test, and `line_total`, which uses the tier
when no discount is given.

```
demo
  price_calc
    tier_discount
      Below 10 units gets no discount [.003 sec]
      Exactly 10 units gets 5 percent [.006 sec] (FAILED - 1)
      49 units still gets 5 percent, 50 gets 10 [.001 sec]
      NULL quantity returns NULL [.002 sec]
    line_total
      Applies an explicit discount [.001 sec]
      Falls back to the tier discount when none is given [.003 sec] (FAILED - 2)
      Rounds to 2 decimals [.001 sec]
      NULL price returns NULL [.001 sec]
      Zero quantity raises -20001 [.004 sec]
      Discount over 100 raises e_bad_discount [.003 sec]
    is_bulk
      50 units is bulk, 49 is not [.002 sec]
    price_list data
      set_price changes the stored price [.002 sec]
      set_price on an unknown SKU raises NO_DATA_FOUND [.003 sec]
      set_price rejects a negative price [.003 sec]
      active_prices returns only active rows at or under the limit, by SKU [.012 sec]

Failures:

  1) tier_at_10
      Actual: 0 (number) was expected to equal: 5 (number)
      at "UTDEMO.TEST_PRICE_CALC.TIER_AT_10", line 12 ut.expect(price_calc.tier_discount(10)).to_equal(5);

  2) total_uses_tier
      Actual: 20 (number) was expected to equal: 19 (number)
      at "UTDEMO.TEST_PRICE_CALC.TOTAL_USES_TIER", line 37 ut.expect(price_calc.line_total(2, 10)).to_equal(19);

Finished in .061387 seconds
15 tests, 2 failed, 0 errored, 0 disabled, 0 warning(s)

declare
*
ERROR at line 1:
ORA-20213: Some tests failed
ORA-06512: at line 12
ORA-06512: at "UT3.UT_RUNNER", line 154
ORA-06512: at line 4


$ echo $?   # shell exit code of the sqlplus run
1
```

### 2. The fix — code, not test

The spec decides which side is wrong. It says 10 units get 5 %, so the code
changes and the assertions stay exactly as they were:

```diff
-    elsif p_qty > 10 then
+    elsif p_qty >= 10 then
       return 5;
```

### 3. Green — same suite, unchanged

```
demo
  price_calc
    tier_discount
      Below 10 units gets no discount [.003 sec]
      Exactly 10 units gets 5 percent [.002 sec]
      49 units still gets 5 percent, 50 gets 10 [.001 sec]
      NULL quantity returns NULL [.001 sec]
    line_total
      Applies an explicit discount [.001 sec]
      Falls back to the tier discount when none is given [.001 sec]
      Rounds to 2 decimals [.001 sec]
      NULL price returns NULL [.001 sec]
      Zero quantity raises -20001 [.006 sec]
      Discount over 100 raises e_bad_discount [.004 sec]
    is_bulk
      50 units is bulk, 49 is not [.002 sec]
    price_list data
      set_price changes the stored price [.002 sec]
      set_price on an unknown SKU raises NO_DATA_FOUND [.005 sec]
      set_price rejects a negative price [.004 sec]
      active_prices returns only active rows at or under the limit, by SKU [.015 sec]

Finished in .067904 seconds
15 tests, 0 failed, 0 errored, 0 disabled, 0 warning(s)

$ echo $?   # shell exit code of the sqlplus run
0
```

After the run, `select count(*) from price_list` returned `0`: the four rows
seeded by `--%beforeall` and the update made by a test were rolled back by
utPLSQL's automatic savepoint.
