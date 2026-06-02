-- ============================================================
-- Migration: RPC topup_balance — nạp thêm tiền trả trước (cộng dồn).
-- Chạy MỘT LẦN trên Supabase SQL Editor cho DB đã tạo trước đó.
-- (Project mới chạy schema.sql là đã có sẵn.)
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
  return v_new;
end $$;
