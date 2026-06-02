-- ============================================================
-- POS Quán Cơm — Supabase schema
-- Chạy toàn bộ file này trong Supabase SQL Editor (1 lần).
-- Tiền lưu bằng integer (VND) để tránh sai số float.
-- ============================================================

-- Cần cho gen_random_uuid()
create extension if not exists pgcrypto;

-- ---------- PRODUCTS ----------
create table if not exists public.products (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  cost_price   integer not null default 0,   -- giá nhập
  sale_price   integer not null default 0,   -- giá bán lẻ
  stock_qty    integer not null default 0,   -- tồn kho
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);

-- ---------- CUSTOMER GROUPS ----------
create table if not exists public.customer_groups (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  benefit_percent numeric(5,2) not null default 0,  -- % giảm mỗi đơn cho nhóm (vd hội viên = 10)
  note            text,
  created_at      timestamptz not null default now()
);

-- ---------- CUSTOMERS ----------
create table if not exists public.customers (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  dob               date,
  phone             text,
  company           text,
  points            numeric(12,2) not null default 0,  -- điểm tích lũy
  is_prepaid_member boolean not null default false,    -- có gói hội viên trả trước
  prepaid_balance   integer not null default 0,        -- số dư trả trước (VND)
  created_at        timestamptz not null default now()
);

-- ---------- CUSTOMER <-> GROUP (n-n) ----------
create table if not exists public.customer_group_members (
  customer_id uuid not null references public.customers(id) on delete cascade,
  group_id    uuid not null references public.customer_groups(id) on delete cascade,
  primary key (customer_id, group_id)
);

-- ---------- DISCOUNTS ----------
create table if not exists public.discounts (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  percent     numeric(5,2) not null default 0,  -- % giảm
  max_uses    integer not null default 0,       -- 0 = vô hạn
  used_count  integer not null default 0,
  expires_at  date,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ---------- MEAL PACKAGES (định nghĩa gói) ----------
create table if not exists public.meal_packages (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  portion_count  integer not null,            -- 30 / 60
  portion_price  integer not null,            -- giá thành phần cố định (vd 35000) = "nhóm giá"
  original_price integer not null,            -- = portion_count * portion_price (hiển thị)
  sale_price     integer not null,            -- giá bán gói (khách trả trước)
  is_active      boolean not null default true,
  created_at     timestamptz not null default now()
);

-- ---------- CUSTOMER PACKAGES (gói đã đăng ký) ----------
create table if not exists public.customer_packages (
  id                uuid primary key default gen_random_uuid(),
  customer_id       uuid not null references public.customers(id) on delete cascade,
  package_id        uuid not null references public.meal_packages(id) on delete restrict,
  credits_total     integer not null,
  credits_remaining integer not null,
  registered_at     timestamptz not null default now(),
  note              text
);

-- ---------- INVOICES ----------
create table if not exists public.invoices (
  id                     uuid primary key default gen_random_uuid(),
  customer_id            uuid references public.customers(id) on delete set null,
  customer_name_snapshot text,
  company_snapshot       text,
  subtotal               integer not null default 0,
  discount_code          text,
  discount_percent       numeric(5,2) not null default 0,
  member_benefit_percent numeric(5,2) not null default 0,
  manual_discount        integer not null default 0,
  total                  integer not null default 0,
  prepaid_used           integer not null default 0,   -- tiền trừ từ số dư trả trước
  points_earned          numeric(12,2) not null default 0,
  is_package_invoice     boolean not null default false,
  customer_package_id    uuid references public.customer_packages(id) on delete set null,
  batch_id               uuid,                 -- gom nhóm khi xuất hàng loạt
  payment_status         text not null default 'pending', -- pending | paid
  paid_at                timestamptz,
  created_at             timestamptz not null default now()
);

-- ---------- INVOICE ITEMS ----------
create table if not exists public.invoice_items (
  id                  uuid primary key default gen_random_uuid(),
  invoice_id          uuid not null references public.invoices(id) on delete cascade,
  product_id          uuid references public.products(id) on delete set null,
  name_snapshot       text not null,
  unit_price          integer not null default 0,
  cost_price_snapshot integer not null default 0,  -- giá vốn TẠI LÚC BÁN (cho báo cáo lãi đúng)
  qty                 integer not null default 1,
  line_total          integer not null default 0,
  from_package        boolean not null default false
);

-- ---------- BALANCE TRANSACTIONS (sổ giao dịch số dư trả trước) ----------
create table if not exists public.balance_transactions (
  id          uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  amount      integer not null,            -- + = nạp, - = tiêu
  kind        text not null,               -- 'topup' | 'spend'
  invoice_id  uuid references public.invoices(id) on delete set null,
  balance_after integer not null default 0,
  created_at  timestamptz not null default now()
);

-- ---------- INDEXES ----------
create index if not exists idx_invoices_customer  on public.invoices(customer_id);
create index if not exists idx_invoices_batch     on public.invoices(batch_id);
create index if not exists idx_invoices_created    on public.invoices(created_at desc);
create index if not exists idx_invoice_items_inv  on public.invoice_items(invoice_id);
create index if not exists idx_discounts_code     on public.discounts(code);
create index if not exists idx_cpkg_customer      on public.customer_packages(customer_id);
create index if not exists idx_baltx_customer     on public.balance_transactions(customer_id, created_at desc);

-- ============================================================
-- RLS — MVP 1 chủ quán: authenticated full access
-- ============================================================
do $$
declare t text;
begin
  foreach t in array array[
    'products','customer_groups','customers','customer_group_members',
    'discounts','meal_packages','customer_packages','invoices','invoice_items',
    'balance_transactions'
  ]
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists "auth_all_%1$s" on public.%1$I;', t);
    execute format($p$create policy "auth_all_%1$s" on public.%1$I
                       for all to authenticated using (true) with check (true);$p$, t);
  end loop;
end $$;

-- ============================================================
-- RPC: create_invoice — tạo hóa đơn nguyên tử
--   p_payload jsonb gồm:
--     customer_id, customer_name, company, discount_code,
--     discount_percent, member_benefit_percent, manual_discount,
--     subtotal, total, points_earned,
--     is_package_invoice, customer_package_id, batch_id,
--     items: [{ product_id, name, unit_price, qty, line_total, from_package }]
--   Trả về invoice id.
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
  -- ===== VALIDATE TRƯỚC (khóa hàng để tránh race) =====

  -- (a) Tồn kho đủ cho từng món? Khóa dòng sản phẩm.
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

  -- (b) Mã giảm còn hiệu lực? (active, chưa hết hạn, còn lượt)
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

  -- (c) Số dư trả trước đủ? Khóa dòng khách.
  if v_cust is not null then
    select prepaid_balance into v_bal from public.customers where id = v_cust for update;
    if v_prepaid > 0 and (v_bal is null or v_bal < v_prepaid) then
      raise exception 'Số dư trả trước không đủ (còn %, cần %)', coalesce(v_bal,0), v_prepaid;
    end if;
  end if;

  -- (d) Credit gói còn? Khóa dòng gói.
  if v_is_pkg and v_cust_pkg is not null then
    select credits_remaining into v_credits
      from public.customer_packages where id = v_cust_pkg for update;
    if v_credits is null or v_credits < 1 then
      raise exception 'Gói đã hết credit';
    end if;
  end if;

  -- ===== GHI =====
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

  -- items + trừ tồn kho + snapshot giá vốn
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
      update public.products
        set stock_qty = stock_qty - v_qty
        where id = v_pid;
    end if;
  end loop;

  -- cộng điểm cho khách
  if v_cust is not null and v_points > 0 then
    update public.customers set points = points + v_points where id = v_cust;
  end if;

  -- tăng lượt dùng mã giảm
  if v_disc_code is not null then
    update public.discounts set used_count = used_count + 1 where code = v_disc_code;
  end if;

  -- trừ credit gói
  if v_is_pkg and v_cust_pkg is not null then
    update public.customer_packages
      set credits_remaining = credits_remaining - 1
      where id = v_cust_pkg;
  end if;

  -- trừ số dư trả trước + ghi sổ giao dịch
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
-- RPC: topup_balance — nạp thêm tiền trả trước (cộng dồn) cho khách.
--   Bật luôn cờ hội viên trả trước. Trả về số dư mới.
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
