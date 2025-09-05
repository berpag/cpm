// lib/data/services/csv_importer.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class CsvImporter {
  static Future<List<List<dynamic>>> importAndParseCsv() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.bytes == null) return [];

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

    if (rows.length < 2) return [];
    
    // Devolvemos las filas de datos (sin los encabezados)
    return rows.sublist(1);
  }
}