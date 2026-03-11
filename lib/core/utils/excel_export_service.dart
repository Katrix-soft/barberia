import 'dart:async';
import 'package:excel/excel.dart';
import '../../features/pos/domain/entities/sale.dart';
import 'package:intl/intl.dart';
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    if (dart.library.io) 'download_helper_mobile.dart';

class ExcelExportService {
  static Future<String?> exportSales(List<Sale> sales) async {
    final Excel excel = Excel.createExcel();
    final Sheet sheet = excel['Ventas'];
    excel.delete('Sheet1');

    // Header style
    CellStyle headerStyle = CellStyle(
      bold: true,
      italic: false,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#C5A028'),
    );

    // Add Headers
    sheet.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Cliente'),
      TextCellValue('Total (\$)'),
      TextCellValue('Método de Pago'),
      TextCellValue('Barbero/Usuario'),
    ]);

    for (int i = 0; i < 5; i++) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
              .cellStyle =
          headerStyle;
    }

    // Add Data
    for (var sale in sales) {
      sheet.appendRow([
        TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(sale.date)),
        TextCellValue(sale.customerName ?? 'Consumidor Final'),
        DoubleCellValue(sale.total),
        TextCellValue(sale.paymentMethod.name.toUpperCase()),
        TextCellValue(sale.userName),
      ]);
    }

    final List<int>? fileBytes = excel.save();

    if (fileBytes != null) {
      final fileName =
          "Reporte_Ventas_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx";
      return DownloadHelper.downloadExcel(fileBytes, fileName);
    }
    return null;
  }
}
