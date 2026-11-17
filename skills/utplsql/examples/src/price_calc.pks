create or replace package price_calc as
  -- Error codes raised by this package
  --   -20001  quantity must be greater than zero
  --   -20002  discount must be between 0 and 100
  --   -20003  unit price cannot be negative
  e_bad_qty      exception; pragma exception_init(e_bad_qty,      -20001);
  e_bad_discount exception; pragma exception_init(e_bad_discount, -20002);
  e_bad_price    exception; pragma exception_init(e_bad_price,    -20003);

  -- Volume discount in percent: 0 below 10 units, 5 from 10 to 49, 10 from 50.
  -- NULL quantity returns NULL.
  function tier_discount(p_qty in number) return number;

  -- unit price * quantity less the discount, rounded to 2 decimals.
  -- p_discount_pct NULL means "use tier_discount". NULL price or quantity returns NULL.
  function line_total(
    p_unit_price   in number,
    p_qty          in number,
    p_discount_pct in number default null
  ) return number;

  -- TRUE from 50 units.
  function is_bulk(p_qty in number) return boolean;

  -- Changes the price of an existing SKU; NO_DATA_FOUND when the SKU does not exist.
  procedure set_price(p_sku in price_list.sku%type, p_unit_price in number);

  -- Active SKUs priced at or below p_max_price: columns SKU, UNIT_PRICE, ordered by SKU.
  function active_prices(p_max_price in number) return sys_refcursor;
end price_calc;
/
