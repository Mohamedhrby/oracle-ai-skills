create or replace package body test_price_calc as

  -- tier_discount ------------------------------------------------------------

  procedure tier_below_10 is
  begin
    ut.expect(price_calc.tier_discount(9)).to_equal(0);
  end;

  procedure tier_at_10 is
  begin
    ut.expect(price_calc.tier_discount(10)).to_equal(5);
  end;

  procedure tier_49_and_50 is
  begin
    ut.expect(price_calc.tier_discount(49)).to_equal(5);
    ut.expect(price_calc.tier_discount(50)).to_equal(10);
  end;

  procedure tier_null_qty is
  begin
    ut.expect(price_calc.tier_discount(null)).to_be_null();
  end;

  -- line_total ---------------------------------------------------------------

  procedure total_explicit_discount is
  begin
    -- 12.50 * 4 = 50.00, less 10 % = 45.00
    ut.expect(price_calc.line_total(12.50, 4, 10)).to_equal(45);
  end;

  procedure total_uses_tier is
  begin
    -- 2.00 * 10 = 20.00, tier gives 5 % = 19.00
    ut.expect(price_calc.line_total(2, 10)).to_equal(19);
  end;

  procedure total_rounds is
  begin
    -- 3.333 * 3 = 9.999 -> 10.00
    ut.expect(price_calc.line_total(3.333, 3, 0)).to_equal(10);
  end;

  procedure total_null_price is
  begin
    ut.expect(price_calc.line_total(null, 5, 0)).to_be_null();
  end;

  procedure total_zero_qty is
    l_total number;
  begin
    l_total := price_calc.line_total(10, 0, 0);
  end;

  procedure total_discount_over_100 is
    l_total number;
  begin
    l_total := price_calc.line_total(10, 1, 101);
  end;

  -- is_bulk ------------------------------------------------------------------

  procedure bulk_threshold is
  begin
    ut.expect(price_calc.is_bulk(50)).to_be_true();
    ut.expect(price_calc.is_bulk(49)).to_be_false();
  end;

  -- price_list data ----------------------------------------------------------
  -- The suite owns its data: the seed clears the table and inserts known rows.
  -- utPLSQL runs the suite inside a savepoint and rolls it back afterwards,
  -- so nothing here is ever committed.

  procedure seed_price_list is
  begin
    delete from price_list;
    insert into price_list (sku, unit_price, active) values ('A-100',  4.00, 'Y');
    insert into price_list (sku, unit_price, active) values ('A-200', 12.50, 'Y');
    insert into price_list (sku, unit_price, active) values ('B-100',  3.00, 'N');
    insert into price_list (sku, unit_price, active) values ('C-100', 99.00, 'Y');
  end;

  procedure set_price_updates_row is
    l_price price_list.unit_price%type;
  begin
    price_calc.set_price('A-100', 4.75);
    select unit_price into l_price from price_list where sku = 'A-100';
    ut.expect(l_price).to_equal(4.75);
  end;

  procedure set_price_unknown_sku is
  begin
    price_calc.set_price('NO-SUCH-SKU', 1);
  end;

  procedure set_price_negative is
  begin
    price_calc.set_price('A-100', -1);
  end;

  procedure active_prices_filters_and_orders is
    l_actual   sys_refcursor;
    l_expected sys_refcursor;
  begin
    open l_expected for
      select 'A-100' as sku, 4.00 as unit_price from dual union all
      select 'A-200',        12.50              from dual;
    l_actual := price_calc.active_prices(p_max_price => 50);
    ut.expect(l_actual).to_equal(l_expected);
  end;

end test_price_calc;
/
