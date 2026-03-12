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
    
    // Use 'Ventas' as the main sheet
    final Sheet sheet = excel['Ventas'];
    excel.delete('Sheet1');

    // Add Headers
    sheet.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Cliente'),
      TextCellValue('Total (\$)'),
      TextCellValue('Método de Pago'),
      TextCellValue('Barbero/Usuario'),
    ]);

    // Header styling
    for (int i = 0; i < 5; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#C5A028'),
      );
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

    // Generate unique filename to avoid "duplicate" download issues
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = "BM_BARBER_Reporte_$timestamp.xlsx";
    
    final List<int>? fileBytes = excel.save();

    if (fileBytes != null) {
      return DownloadHelper.downloadExcel(fileBytes, fileName);
    }
    return null;
  }
}
