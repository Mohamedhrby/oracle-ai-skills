-- Installs the example into the current (dev/test) schema.
-- Run from this folder:  sqlplus user/pass@//host:port/service @install.sql
whenever sqlerror exit failure
whenever oserror exit failure
set define off

@src/price_list.sql
@src/price_calc.pks
@src/price_calc.pkb
@test/test_price_calc.pks
@test/test_price_calc.pkb

-- create or replace with compile errors is only a warning: check explicitly
declare
  l_bad pls_integer;
begin
  select count(*) into l_bad from user_objects
   where object_name in ('PRICE_CALC', 'TEST_PRICE_CALC') and status <> 'VALID';
  if l_bad > 0 then
    raise_application_error(-20999, l_bad || ' invalid object(s); see user_errors');
  end if;
end;
/
exit
