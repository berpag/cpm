// lib/data/services/csv_importer.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class CsvImporter {
  /// Importa un archivo CSV y lo parsea.
  ///
  /// Devuelve un mapa con dos claves:
  /// - 'rows': Una `List<List<dynamic>>` con las filas de datos.
  /// - 'content': Un `String` con el contenido crudo del archivo CSV.
  ///
  /// Devuelve `null` si el usuario cancela la selección de archivo.
  static Future<Map<String, dynamic>?> importAndParseCsv() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.bytes == null) return null;

    final Uint8List fileBytes = result.files.single.bytes!;
    String csvString;
    try {
      csvString = utf8.decode(fileBytes);
    } catch (e) {
      csvString = latin1.decode(fileBytes);
    }

    final lines = csvString.split('\n');
    int headerRowIndex = lines.indexWhere((line) => line.contains('"User_ID"') && line.contains('"UTC_Time"'));
    if (headerRowIndex == -1) throw Exception("Encabezado de CSV no encontrado.");

    final validCsvData = lines.sublist(headerRowIndex).join('\n');
    
    final rows = const CsvToListConverter(fieldDelimiter: ',', textDelimiter: '"', eol: '\n').convert(validCsvData);

    if (rows.length < 2) return null;
    
    // Devolvemos tanto las filas de datos (sin los encabezados) como el contenido original
    return {
      'rows': rows.sublist(1),
      'content': csvString,
    };
  }
}