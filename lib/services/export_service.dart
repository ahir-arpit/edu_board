import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/stroke.dart';
import '../models/geometry_shape.dart';

class ExportService {
  final ScreenshotController screenshotController = ScreenshotController();

  /// Captures a screenshot of the whiteboard widget wrapped in a Screenshot widget.
  Future<Uint8List?> captureCanvas(Widget canvasWidget) async {
    try {
      return await screenshotController.captureFromWidget(
        canvasWidget,
        delay: const Duration(milliseconds: 50),
      );
    } catch (e) {
      debugPrint("Error capturing canvas image: $e");
      return null;
    }
  }

  /// Exports drawing strokes locally to a PDF document in Flutter.
  Future<File> generateLocalPdf(String title, Uint8List canvasImage) async {
    final pdf = pw.Document();
    
    // Add canvas screenshot as a page in the PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter.landscape,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Expanded(
                  child: pw.Image(
                    pw.MemoryImage(canvasImage),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final file = File("${outputDir.path}/smartboard_export_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Directly sends an export PDF/Image file to native share intents.
  Future<void> shareFile({
    required String filePath,
    required String subject,
    required String text,
  }) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: text,
        subject: subject,
      );
    } catch (e) {
      debugPrint("Error sharing file: $e");
    }
  }

  /// Triggers a print preview dialog directly from the device.
  Future<void> printCanvas(Uint8List canvasImage) async {
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter.landscape,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                pw.MemoryImage(canvasImage),
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
      );
    } catch (e) {
      debugPrint("Printing failed: $e");
    }
  }

  /// Calls the backend server to render a high-quality vector PDF
  Future<File?> generateVectorPdfFromServer(String title, List<List<dynamic>> pages) async {
    try {
      final url = Uri.parse("${AppConstants.apiBaseUrl}/export/pdf");
      
      // Serialize pages
      final serializedPages = pages.map((pageItems) {
        return pageItems.map((item) {
          if (item is Stroke) {
            return item.toJson();
          } else if (item is GeometryShape) {
            return item.toJson();
          }
          return item;
        }).toList();
      }).toList();

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "title": title,
          "pages": serializedPages,
        }),
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final outputDir = await getTemporaryDirectory();
        final file = File("${outputDir.path}/smartboard_vector_${DateTime.now().millisecondsSinceEpoch}.pdf");
        await file.writeAsBytes(bytes);
        return file;
      } else {
        debugPrint("Server vector PDF export failed: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error exporting vector PDF: $e");
      return null;
    }
  }
}

// Riverpod Provider
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});
