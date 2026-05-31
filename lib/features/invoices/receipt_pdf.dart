import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/money.dart';
import '../../domain/models/invoice.dart';

/// Tạo + in/chia sẻ biên lai khổ nhiệt (~80mm).
///
/// Lưu ý: dùng font Google (Roboto) hỗ trợ tiếng Việt — lần đầu cần internet
/// để tải font. Có thể nhúng font asset sau để in offline.
class ReceiptPdf {
  static Future<Uint8List> build(Invoice i) async {
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    final df = DateFormat('dd/MM/yyyy HH:mm');

    final doc = pw.Document();
    final theme = pw.ThemeData.withFont(base: base, bold: bold);

    final cash = i.total - i.prepaidUsed;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: theme,
        build: (ctx) {
          pw.Widget kv(String k, String v, {bool bold = false}) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(k,
                      style: pw.TextStyle(
                          fontSize: bold ? 11 : 9,
                          fontWeight:
                              bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
                  pw.Text(v,
                      style: pw.TextStyle(
                          fontSize: bold ? 12 : 9,
                          fontWeight:
                              bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
                ],
              );

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text('QUÁN CƠM',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(child: pw.Text('HÓA ĐƠN BÁN HÀNG')),
              if (i.isPackageInvoice)
                pw.Center(child: pw.Text('(Hóa đơn theo gói)')),
              pw.Divider(),
              kv('Mã HĐ', i.id.substring(0, 8)),
              kv('Thời gian', df.format(i.createdAt)),
              if (i.customerNameSnapshot != null)
                kv('Khách', i.customerNameSnapshot!),
              if (i.companySnapshot != null) kv('Công ty', i.companySnapshot!),
              pw.Divider(),
              for (final it in i.items)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${it.nameSnapshot} x${it.qty}'
                        '${it.fromPackage ? ' (gói)' : ''}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Text(
                      it.fromPackage ? '0' : Money.plain(it.lineTotal),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              pw.Divider(),
              kv('Tạm tính', Money.format(i.subtotal)),
              if (i.discountPercent > 0)
                kv('Mã ${i.discountCode ?? ''}',
                    '-${i.discountPercent.toInt()}%'),
              if (i.memberBenefitPercent > 0)
                kv('Ưu đãi', '-${i.memberBenefitPercent.toInt()}%'),
              if (i.manualDiscount > 0)
                kv('Giảm tay', '-${Money.format(i.manualDiscount)}'),
              kv('TỔNG', Money.format(i.total), bold: true),
              if (i.prepaidUsed > 0) ...[
                kv('Trả từ số dư', '-${Money.format(i.prepaidUsed)}'),
                kv('Tiền mặt', Money.format(cash), bold: true),
              ],
              kv('Điểm tích', '+${i.pointsEarned.toStringAsFixed(2)}'),
              pw.SizedBox(height: 8),
              pw.Center(child: pw.Text('Cảm ơn quý khách!')),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Mở hộp thoại in của hệ điều hành.
  static Future<void> print(Invoice i) async {
    await Printing.layoutPdf(onLayout: (_) => build(i));
  }

  /// Chia sẻ file PDF (email/zalo/lưu...).
  static Future<void> share(Invoice i) async {
    final bytes = await build(i);
    await Printing.sharePdf(
        bytes: bytes, filename: 'bien-lai-${i.id.substring(0, 8)}.pdf');
  }
}
