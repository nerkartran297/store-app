# POS Quán Cơm — Flutter + Supabase

MVP hệ thống bán hàng (POS) cho quán cơm: bán hàng tại quầy, quản lý sản phẩm/tồn kho,
mã giảm giá, nhóm khách, gói phần ăn (30/60 phần), hội viên trả trước, tích điểm.

## Stack
- Flutter (Android-first) · Riverpod · go_router
- Supabase (Postgres + Auth)
- Logic tính tiền thuần Dart (`lib/core/pricing/pricing_engine.dart`) + unit test

## Thiết lập Supabase (1 lần)

1. Tạo project tại https://supabase.com → lấy **Project URL** + **anon public key**
   (Settings → API).
2. Mở **SQL Editor**, chạy lần lượt:
   - `supabase/schema.sql` (bảng + RLS + RPC `create_invoice`)
   - `supabase/seed.sql` (dữ liệu mẫu: menu, mã giảm, nhóm khách, gói, khách demo)
3. Tạo tài khoản chủ quán: **Authentication → Users → Add user**
   (nhập email + password; tắt "Auto Confirm" thì nhớ xác nhận email).

## Chạy app

```bash
flutter pub get

flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

> App đọc URL/key qua `--dart-define` để không hardcode khóa vào source.
> Thiếu cấu hình → app hiển thị màn hướng dẫn thay vì crash.

Build APK:
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Kiểm thử

```bash
flutter test       # unit test pricing engine
flutter analyze    # 0 issues
```

## Cấu trúc

```
lib/
  core/        config, theme, router, utils, pricing engine
  data/        supabase client, repositories, providers
  domain/      models
  features/    auth, dashboard, sales(POS), products, discounts,
               customer_groups, customers, packages, invoices
supabase/      schema.sql, seed.sql
```

## Nghiệp vụ chính đã có
- **Bán hàng**: chọn món → chọn khách (modal hỏi áp ưu đãi nhóm/hội viên) →
  mã giảm → giảm tay → breakdown realtime → chốt → xác nhận thanh toán →
  lưu (trừ tồn kho, cộng điểm, tăng lượt mã) qua RPC nguyên tử.
- **Gói phần ăn**: định nghĩa gói (số phần × giá suất cố định = "nhóm giá").
  Xuất **lẻ** (1 người, trừ 1 credit) và **hàng loạt** theo công ty
  (đánh dấu vắng → giữ credit, gom chung `batch_id`).
- **Tích điểm**: 1 điểm / 10.000đ, làm tròn 2 chữ số.
- **Giảm giá chồng tuần tự**: subtotal → %mã → %hội viên → giảm tay.
```
