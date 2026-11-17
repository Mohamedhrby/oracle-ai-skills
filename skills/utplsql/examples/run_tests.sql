-- Runs the example suite, prints the documentation report, and exits
-- non-zero when any test fails or errors (plain "exec ut.run" always exits 0).
whenever sqlerror exit failure
set serveroutput on size unlimited format wrapped
set linesize 200 feedback off
declare
  l_reporter ut_documentation_reporter := ut_documentation_reporter();
begin
  ut_runner.run(
    a_paths          => ut_varchar2_list('test_price_calc'),
    a_reporters      => ut_reporters(l_reporter),
    a_fail_on_errors => true);
  l_reporter.lines_to_dbms_output();
exception
  when others then
    l_reporter.lines_to_dbms_output();   -- print the report, then fail the script
    raise;
end;
/
exit
