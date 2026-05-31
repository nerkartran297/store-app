-- ============================================================
-- POS Quán Cơm — Seed data demo
-- Chạy SAU schema.sql trong Supabase SQL Editor.
-- ============================================================

-- ---------- SẢN PHẨM (menu cơm) ----------
insert into public.products (name, cost_price, sale_price, stock_qty) values
  ('Cơm sườn',          22000, 35000, 100),
  ('Cơm gà',            20000, 35000, 100),
  ('Cơm sườn bì chả',   28000, 45000,  80),
  ('Cơm chả trứng',     26000, 45000,  80),
  ('Cơm tấm đặc biệt',  35000, 55000,  60),
  ('Canh chua',          8000, 15000, 120),
  ('Trà đá',             1000,  5000, 300),
  ('Nước ngọt',          6000, 12000, 200);

-- ---------- NHÓM KHÁCH ----------
insert into public.customer_groups (name, benefit_percent, note) values
  ('Khách thường',     0,  'Nhóm mặc định'),
  ('Sinh viên',        5,  'Ưu đãi sinh viên'),
  ('Nhân viên VP',     5,  'Đặt cơm văn phòng'),
  ('Khách VIP',        10, 'Khách thân thiết'),
  ('Hội viên trả trước', 10, 'Trả trước nhận ưu đãi 10%/đơn');

-- ---------- MÃ GIẢM GIÁ ----------
insert into public.discounts (code, percent, max_uses, expires_at) values
  ('SINHVIEN',   5,  0,    '2026-12-31'),
  ('KHACHVIP',   10, 0,    '2026-12-31'),
  ('NHANVIENVP', 8,  0,    '2026-12-31'),
  ('SALE304',    15, 100,  '2026-05-04');

-- ---------- GÓI PHẦN ĂN ----------
-- Gói 30 phần suất 35k: gốc 1.050.000 -> bán 850.000
-- Gói 60 phần suất 35k: gốc 2.100.000 -> bán 1.650.000
-- Gói 30 phần suất 45k: gốc 1.350.000 -> bán 1.150.000
insert into public.meal_packages (name, portion_count, portion_price, original_price, sale_price) values
  ('Gói 30 phần — suất 35k', 30, 35000, 1050000, 850000),
  ('Gói 60 phần — suất 35k', 60, 35000, 2100000, 1650000),
  ('Gói 30 phần — suất 45k', 30, 45000, 1350000, 1150000);

-- ---------- KHÁCH HÀNG DEMO ----------
insert into public.customers (name, phone, company, is_prepaid_member, prepaid_balance) values
  ('Nguyễn Văn A', '0900000001', null, false, 0),
  ('Trần Thị B',   '0900000002', 'Công ty FPT', false, 0),
  ('Lê Văn C',     '0900000003', 'Công ty FPT', false, 0),
  ('Phạm Hội Viên','0900000004', null, true, 900000);

-- Gán nhóm + đăng ký gói demo (dùng DO block để lấy id)
do $$
declare
  c_a uuid; c_b uuid; c_c uuid; c_hv uuid;
  g_sv uuid; g_vp uuid; g_hv uuid;
  pkg30 uuid;
begin
  select id into c_a  from public.customers where phone='0900000001';
  select id into c_b  from public.customers where phone='0900000002';
  select id into c_c  from public.customers where phone='0900000003';
  select id into c_hv from public.customers where phone='0900000004';

  select id into g_sv from public.customer_groups where name='Sinh viên';
  select id into g_vp from public.customer_groups where name='Nhân viên VP';
  select id into g_hv from public.customer_groups where name='Hội viên trả trước';

  select id into pkg30 from public.meal_packages where name='Gói 30 phần — suất 35k';

  insert into public.customer_group_members(customer_id, group_id) values
    (c_a, g_sv),
    (c_b, g_vp),
    (c_c, g_vp),
    (c_hv, g_hv)
  on conflict do nothing;

  -- Sinh viên A đăng ký gói 30 phần
  insert into public.customer_packages(customer_id, package_id, credits_total, credits_remaining)
    values (c_a, pkg30, 30, 30);

  -- Cả 2 nhân viên FPT đăng ký gói 30 phần (xuất hàng loạt theo công ty)
  insert into public.customer_packages(customer_id, package_id, credits_total, credits_remaining)
    values (c_b, pkg30, 30, 30), (c_c, pkg30, 30, 30);
end $$;
