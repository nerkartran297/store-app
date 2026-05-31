-- ============================================================
-- Migration: thêm cột prepaid_used + cập nhật RPC create_invoice
-- Chạy file này MỘT LẦN trên Supabase SQL Editor cho DB đã tạo trước đó.
-- (Project mới chạy schema.sql là đã có sẵn, không cần file này.)
-- ============================================================

-- 1) Thêm cột số dư trả trước đã dùng vào hóa đơn
alter table public.invoices
  add column if not exists prepaid_used integer not null default 0;

-- 2) Thay thế RPC create_invoice (bản có xử lý prepaid_used)
create or replace function public.create_invoice(p_payload jsonb)
returns uuid
language plpgsql
security definer
as $$
declare
  v_invoice_id uuid;
  v_item       jsonb;
  v_is_pkg     boolean := coalesce((p_payload->>'is_package_invoice')::boolean, false);
  v_cust_pkg   uuid := nullif(p_payload->>'customer_package_id','')::uuid;
  v_disc_code  text := nullif(p_payload->>'discount_code','');
  v_total      integer := coalesce((p_payload->>'total')::integer, 0);
  v_cust       uuid := nullif(p_payload->>'customer_id','')::uuid;
  v_points     numeric := coalesce((p_payload->>'points_earned')::numeric, 0);
  v_prepaid    integer := coalesce((p_payload->>'prepaid_used')::integer, 0);
begin
  insert into public.invoices (
    customer_id, customer_name_snapshot, company_snapshot,
    subtotal, discount_code, discount_percent, member_benefit_percent,
    manual_discount, total, prepaid_used, points_earned,
    is_package_invoice, customer_package_id, batch_id,
    payment_status, paid_at
  ) values (
    v_cust,
    nullif(p_payload->>'customer_name',''),
    nullif(p_payload->>'company',''),
    coalesce((p_payload->>'subtotal')::integer,0),
    v_disc_code,
    coalesce((p_payload->>'discount_percent')::numeric,0),
    coalesce((p_payload->>'member_benefit_percent')::numeric,0),
    coalesce((p_payload->>'manual_discount')::integer,0),
    v_total,
    v_prepaid,
    v_points,
    v_is_pkg,
    v_cust_pkg,
    nullif(p_payload->>'batch_id','')::uuid,
    'paid',
    now()
  ) returning id into v_invoice_id;

  for v_item in select * from jsonb_array_elements(coalesce(p_payload->'items','[]'::jsonb))
  loop
    insert into public.invoice_items (
      invoice_id, product_id, name_snapshot, unit_price, qty, line_total, from_package
    ) values (
      v_invoice_id,
      nullif(v_item->>'product_id','')::uuid,
      v_item->>'name',
      coalesce((v_item->>'unit_price')::integer,0),
      coalesce((v_item->>'qty')::integer,1),
      coalesce((v_item->>'line_total')::integer,0),
      coalesce((v_item->>'from_package')::boolean,false)
    );

    if (v_item->>'product_id') is not null and (v_item->>'product_id') <> '' then
      update public.products
        set stock_qty = stock_qty - coalesce((v_item->>'qty')::integer,1)
        where id = (v_item->>'product_id')::uuid;
    end if;
  end loop;

  if v_cust is not null and v_points > 0 then
    update public.customers set points = points + v_points where id = v_cust;
  end if;

  if v_disc_code is not null then
    update public.discounts set used_count = used_count + 1 where code = v_disc_code;
  end if;

  if v_is_pkg and v_cust_pkg is not null then
    update public.customer_packages
      set credits_remaining = greatest(0, credits_remaining - 1)
      where id = v_cust_pkg;
  end if;

  if v_cust is not null and v_prepaid > 0 then
    update public.customers
      set prepaid_balance = greatest(0, prepaid_balance - v_prepaid)
      where id = v_cust;
  end if;

  return v_invoice_id;
end $$;
