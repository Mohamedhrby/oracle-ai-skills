-- Synthetic demo table for the price_calc example. No real data.
create table price_list (
  sku        varchar2(20) constraint price_list_pk primary key,
  unit_price number(10,2) not null constraint price_list_price_ck check (unit_price >= 0),
  active     varchar2(1)  default 'Y' not null constraint price_list_active_ck check (active in ('Y','N'))
);
