// ignore_for_file: avoid_print
// Script CLI (chạy bằng `dart run`), print là cách xuất log đúng ở đây.
//
// Script thiết lập DB Supabase: chạy schema.sql + seed.sql + tạo user chủ quán.
//
// Cấu hình qua file .env ở thư mục gốc (ưu tiên), hoặc biến môi trường:
//   PG_URL=postgresql://postgres:<DB_PASSWORD>@db.<ref>.supabase.co:5432/postgres
//   OWNER_EMAIL=chuquan@quan.com
//   OWNER_PASSWORD=matkhau123
//
//   dart run tool/db_setup.dart
//
// Lấy PG_URL ở: Supabase Dashboard -> Connect (direct hoặc session pooler).
// (.env đã được .gitignore — không commit.)
//
// Cờ tùy chọn:
//   --no-seed     bỏ qua seed.sql
//   --no-user     bỏ qua tạo user
//   --reset       DROP toàn bộ bảng trước khi tạo lại (cẩn thận!)

import 'dart:io';

import 'package:postgres/postgres.dart';

/// Đọc file .env đơn giản (KEY=VALUE mỗi dòng, bỏ qua # và dòng trống).
/// Tự trim khoảng trắng quanh key và value (chấp nhận "KEY = value").
Map<String, String> _loadDotEnv([String path = '.env']) {
  final file = File(path);
  if (!file.existsSync()) return {};
  final out = <String, String>{};
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq < 0) continue;
    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();
    // Bỏ dấu nháy bao quanh nếu có.
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    if (key.isNotEmpty) out[key] = value;
  }
  return out;
}

Future<void> main(List<String> args) async {
  final env = _loadDotEnv();
  // .env ưu tiên; fallback sang biến môi trường hệ thống.
  String? cfg(String k) => env[k] ?? Platform.environment[k];

  final urlStr = cfg('PG_URL');
  final ownerEmail = cfg('OWNER_EMAIL');
  final ownerPassword = cfg('OWNER_PASSWORD');

  final skipSeed = args.contains('--no-seed');
  final skipUser = args.contains('--no-user');
  final reset = args.contains('--reset');

  if (urlStr == null || urlStr.isEmpty) {
    stderr.writeln('Thiếu PG_URL. Xem hướng dẫn ở đầu file tool/db_setup.dart');
    exit(1);
  }

  final uri = Uri.parse(urlStr);
  final userInfo = uri.userInfo.split(':');
  final endpoint = Endpoint(
    host: uri.host,
    port: uri.port == 0 ? 5432 : uri.port,
    database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'postgres',
    username: Uri.decodeComponent(userInfo.first),
    password: userInfo.length > 1 ? Uri.decodeComponent(userInfo[1]) : null,
  );

  print('🔌 Kết nối ${endpoint.host}:${endpoint.port} ...');
  final conn = await Connection.open(
    endpoint,
    settings: const ConnectionSettings(sslMode: SslMode.require),
  );
  print('✅ Đã kết nối.');

  try {
    if (reset) {
      print('🗑️  --reset: xóa các bảng cũ ...');
      await conn.execute('''
        drop table if exists public.invoice_items cascade;
        drop table if exists public.invoices cascade;
        drop table if exists public.customer_packages cascade;
        drop table if exists public.meal_packages cascade;
        drop table if exists public.customer_group_members cascade;
        drop table if exists public.discounts cascade;
        drop table if exists public.customers cascade;
        drop table if exists public.customer_groups cascade;
        drop table if exists public.products cascade;
        drop function if exists public.create_invoice(jsonb) cascade;
      ''', queryMode: QueryMode.simple);
    }

    await _runFile(conn, 'supabase/schema.sql', 'schema');
    if (!skipSeed) await _runFile(conn, 'supabase/seed.sql', 'seed');

    if (!skipUser) {
      if (ownerEmail == null || ownerPassword == null) {
        print('⚠️  Bỏ qua tạo user (thiếu OWNER_EMAIL/OWNER_PASSWORD).');
      } else {
        await _createOwner(conn, ownerEmail, ownerPassword);
      }
    }

    print('\n🎉 Hoàn tất! App sẵn sàng đăng nhập.');
  } finally {
    await conn.close();
  }
}

Future<void> _runFile(Connection conn, String path, String label) async {
  final sql = await File(path).readAsString();
  print('▶️  Chạy $label ($path) ...');
  // Postgres simple-protocol cho phép nhiều statement trong 1 chuỗi.
  await conn.execute(sql, queryMode: QueryMode.simple);
  print('✅ Xong $label.');
}

/// Tạo user trong auth.users (Supabase GoTrue). Dùng pgcrypto crypt() để hash.
/// Không dùng ON CONFLICT (auth.users không có unique index khớp) — tự kiểm tra.
Future<void> _createOwner(
    Connection conn, String email, String password) async {
  print('👤 Tạo/cập nhật tài khoản chủ quán: $email ...');

  final existing = await conn.execute(
    r'select id from auth.users where email = $1 limit 1',
    parameters: [email],
  );

  String userId;
  if (existing.isNotEmpty) {
    // Đã có -> cập nhật mật khẩu + xác nhận email.
    userId = existing.first.first as String;
    await conn.execute(
      r'''
      update auth.users
        set encrypted_password = crypt($2, gen_salt('bf')),
            email_confirmed_at = coalesce(email_confirmed_at, now()),
            updated_at = now()
        where email = $1
      ''',
      parameters: [email, password],
    );
    print('✅ Đã cập nhật mật khẩu cho user sẵn có.');
  } else {
    final inserted = await conn.execute(
      r'''
      insert into auth.users (
        instance_id, id, aud, role, email,
        encrypted_password, email_confirmed_at,
        created_at, updated_at,
        raw_app_meta_data, raw_user_meta_data
      ) values (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(), 'authenticated', 'authenticated', $1,
        crypt($2, gen_salt('bf')), now(),
        now(), now(),
        '{"provider":"email","providers":["email"]}', '{}'
      )
      returning id
      ''',
      parameters: [email, password],
    );
    userId = inserted.first.first as String;
    print('✅ Đã tạo user mới.');
  }

  // VÁ các cột token: GoTrue trả 500 "Database error querying schema" nếu
  // các cột này là NULL (insert SQL tay để NULL). Đặt về chuỗi rỗng.
  await conn.execute(
    r'''
    update auth.users set
      confirmation_token = coalesce(confirmation_token, ''),
      recovery_token = coalesce(recovery_token, ''),
      email_change = coalesce(email_change, ''),
      email_change_token_new = coalesce(email_change_token_new, ''),
      email_change_token_current = coalesce(email_change_token_current, ''),
      phone_change = coalesce(phone_change, ''),
      phone_change_token = coalesce(phone_change_token, ''),
      reauthentication_token = coalesce(reauthentication_token, '')
    where id = $1::uuid
    ''',
    parameters: [userId],
  );
  print('✅ Đã vá các cột token rỗng.');

  // Đảm bảo identity email tồn tại (GoTrue mới cần để login). Tự lành lại
  // trạng thái nửa-vời nếu lần chạy trước tạo user mà chưa tạo identity.
  final hasIdentity = await conn.execute(
    r"select 1 from auth.identities where user_id = $1::uuid and provider = 'email' limit 1",
    parameters: [userId],
  );
  if (hasIdentity.isEmpty) {
    await conn.execute(
      r'''
      insert into auth.identities (
        provider_id, user_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
      ) values (
        $1::uuid, $2::uuid,
        jsonb_build_object('sub', $3::text, 'email', $4::text, 'email_verified', true),
        'email', now(), now(), now()
      )
      ''',
      parameters: [userId, userId, userId, email],
    );
    print('✅ Đã tạo identity email.');
  } else {
    print('✅ Identity email đã có.');
  }
}
