-- ============================================================
-- Migration: Hardening sau review
--   #1 chặn oversell (trong RPC), #2/#3 validate mã/số dư/credit,
--   #8 snapshot giá vốn (cột mới), #6 sổ giao dịch số dư (bảng mới).
-- Chạy MỘT LẦN trên Supabase SQL Editor cho DB đã tạo trước đó.
-- (Project mới chạy schema.sql là đã có sẵn.)
-- ============================================================

-- #8: cột giá vốn snapshot
alter table public.invoice_items
  add column if not exists cost_price_snapshot integer not null default 0;

-- #6: bảng sổ giao dịch số dư
create table if not exists public.balance_transactions (
  id            uuid primary key default gen_random_uuid(),
  customer_id   uuid not null references public.customers(id) on delete cascade,
  amount        integer not null,
  kind          text not null,
  invoice_id    uuid references public.invoices(id) on delete set null,
  balance_after integer not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists idx_baltx_customer
  on public.balance_transactions(customer_id, created_at desc);

-- RLS cho bảng mới
alter table public.balance_transactions enable row level security;
drop policy if exists "auth_all_balance_transactions" on public.balance_transactions;
create policy "auth_all_balance_transactions" on public.balance_transactions
  for all to authenticated using (true) with check (true);

-- ============================================================
-- RPC create_invoice (bản hardened)
-- ============================================================
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
  v_pid        uuid;
  v_qty        integer;
  v_stock      integer;
  v_cost       integer;
  v_bal        integer;
  v_credits    integer;
begin
  -- (a) tồn kho
  for v_item in select * from jsonb_array_elements(coalesce(p_payload->'items','[]'::jsonb))
  loop
    v_pid := nullif(v_item->>'product_id','')::uuid;
    v_qty := coalesce((v_item->>'qty')::integer, 1);
    if v_pid is not null then
      select stock_qty into v_stock from public.products where id = v_pid for update;
      if v_stock is null then
        raise exception 'Sản phẩm không tồn tại';
      end if;
      if v_stock < v_qty then
        raise exception 'Không đủ tồn kho cho "%": còn %, cần %',
          (v_item->>'name'), v_stock, v_qty;
      end if;
    end if;
  end loop;

  -- (b) mã giảm
  if v_disc_code is not null then
    perform 1 from public.discounts
      where code = v_disc_code
        and is_active = true
        and (expires_at is null or expires_at >= current_date)
        and (max_uses = 0 or used_count < max_uses)
      for update;
    if not found then
      raise exception 'Mã giảm "%" không dùng được (hết hạn/hết lượt)', v_disc_code;
    end if;
  end if;

  -- (c) số dư
  if v_cust is not null then
    select prepaid_balance into v_bal from public.customers where id = v_cust for update;
    if v_prepaid > 0 and (v_bal is null or v_bal < v_prepaid) then
      raise exception 'Số dư trả trước không đủ (còn %, cần %)', coalesce(v_bal,0), v_prepaid;
    end if;
  end if;

  -- (d) credit gói
  if v_is_pkg and v_cust_pkg is not null then
    select credits_remaining into v_credits
      from public.customer_packages where id = v_cust_pkg for update;
    if v_credits is null or v_credits < 1 then
      raise exception 'Gói đã hết credit';
    end if;
  end if;

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
    v_pid := nullif(v_item->>'product_id','')::uuid;
    v_qty := coalesce((v_item->>'qty')::integer, 1);
    v_cost := 0;
    if v_pid is not null then
      select cost_price into v_cost from public.products where id = v_pid;
    end if;

    insert into public.invoice_items (
      invoice_id, product_id, name_snapshot, unit_price,
      cost_price_snapshot, qty, line_total, from_package
    ) values (
      v_invoice_id,
      v_pid,
      v_item->>'name',
      coalesce((v_item->>'unit_price')::integer,0),
      coalesce(v_cost, 0),
      v_qty,
      coalesce((v_item->>'line_total')::integer,0),
      coalesce((v_item->>'from_package')::boolean,false)
    );

    if v_pid is not null then
      update public.products set stock_qty = stock_qty - v_qty where id = v_pid;
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
      set credits_remaining = credits_remaining - 1
      where id = v_cust_pkg;
  end if;

  if v_cust is not null and v_prepaid > 0 then
    update public.customers
      set prepaid_balance = prepaid_balance - v_prepaid
      where id = v_cust
      returning prepaid_balance into v_bal;
    insert into public.balance_transactions(customer_id, amount, kind, invoice_id, balance_after)
      values (v_cust, -v_prepaid, 'spend', v_invoice_id, v_bal);
  end if;

  return v_invoice_id;
end $$;

-- ============================================================
-- RPC topup_balance (ghi sổ giao dịch)
-- ============================================================
create or replace function public.topup_balance(
  p_customer_id uuid,
  p_amount integer
)
returns integer
language plpgsql
security definer
as $$
declare
  v_new integer;
begin
  if p_amount is null or p_amount <= 0 then
    raise exception 'Số tiền nạp phải lớn hơn 0';
  end if;
  update public.customers
    set prepaid_balance = prepaid_balance + p_amount,
        is_prepaid_member = true
    where id = p_customer_id
    returning prepaid_balance into v_new;
  if v_new is null then
    raise exception 'Khách hàng không tồn tại';
  end if;
  insert into public.balance_transactions(customer_id, amount, kind, balance_after)
    values (p_customer_id, p_amount, 'topup', v_new);
  return v_new;
end $$;
