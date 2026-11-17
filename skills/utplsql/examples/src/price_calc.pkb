create or replace package body price_calc as

  function tier_discount(p_qty in number) return number is
  begin
    if p_qty is null then
      return null;
    elsif p_qty >= 50 then
      return 10;
    elsif p_qty >= 10 then
      return 5;
    else
      return 0;
    end if;
  end tier_discount;

  function line_total(
    p_unit_price   in number,
    p_qty          in number,
    p_discount_pct in number default null
  ) return number is
    l_discount number;
  begin
    if p_unit_price is null or p_qty is null then
      return null;
    end if;
    if p_qty <= 0 then
      raise_application_error(-20001, 'Quantity must be greater than zero, got ' || p_qty);
    end if;
    l_discount := nvl(p_discount_pct, tier_discount(p_qty));
    if l_discount not between 0 and 100 then
      raise_application_error(-20002, 'Discount must be between 0 and 100, got ' || l_discount);
    end if;
    return round(p_unit_price * p_qty * (100 - l_discount) / 100, 2);
  end line_total;

  function is_bulk(p_qty in number) return boolean is
  begin
    return p_qty >= 50;
  end is_bulk;

  procedure set_price(p_sku in price_list.sku%type, p_unit_price in number) is
  begin
    if p_unit_price < 0 then
      raise_application_error(-20003, 'Unit price cannot be negative: ' || p_unit_price);
    end if;
    update price_list set unit_price = p_unit_price where sku = p_sku;
    if sql%rowcount = 0 then
      raise no_data_found;
    end if;
  end set_price;

  function active_prices(p_max_price in number) return sys_refcursor is
    l_rc sys_refcursor;
  begin
    open l_rc for
      select sku, unit_price
        from price_list
       where active = 'Y'
         and unit_price <= p_max_price
       order by sku;
    return l_rc;
  end active_prices;

end price_calc;
/
