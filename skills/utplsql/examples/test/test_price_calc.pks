create or replace package test_price_calc as
  --%suite(price_calc)
  --%suitepath(demo)

  --%context(tier_discount)

    --%test(Below 10 units gets no discount)
    procedure tier_below_10;

    --%test(Exactly 10 units gets 5 percent)
    procedure tier_at_10;

    --%test(49 units still gets 5 percent, 50 gets 10)
    procedure tier_49_and_50;

    --%test(NULL quantity returns NULL)
    procedure tier_null_qty;

  --%endcontext

  --%context(line_total)

    --%test(Applies an explicit discount)
    procedure total_explicit_discount;

    --%test(Falls back to the tier discount when none is given)
    procedure total_uses_tier;

    --%test(Rounds to 2 decimals)
    procedure total_rounds;

    --%test(NULL price returns NULL)
    procedure total_null_price;

    --%test(Zero quantity raises -20001)
    --%throws(-20001)
    procedure total_zero_qty;

    --%test(Discount over 100 raises e_bad_discount)
    --%throws(price_calc.e_bad_discount)
    procedure total_discount_over_100;

  --%endcontext

  --%context(is_bulk)

    --%test(50 units is bulk, 49 is not)
    procedure bulk_threshold;

  --%endcontext

  --%context(price_list data)

    --%beforeall
    procedure seed_price_list;

    --%test(set_price changes the stored price)
    procedure set_price_updates_row;

    --%test(set_price on an unknown SKU raises NO_DATA_FOUND)
    --%throws(no_data_found)
    procedure set_price_unknown_sku;

    --%test(set_price rejects a negative price)
    --%throws(price_calc.e_bad_price)
    procedure set_price_negative;

    --%test(active_prices returns only active rows at or under the limit, by SKU)
    procedure active_prices_filters_and_orders;

  --%endcontext

end test_price_calc;
/
