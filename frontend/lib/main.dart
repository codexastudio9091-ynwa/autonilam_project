import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MaterialApp(
    home: AutoNilamDashboard(),
    debugShowCheckedModeBanner: false,
  ));
}

class AutoNilamDashboard extends StatefulWidget {
  const AutoNilamDashboard({super.key});

  @override
  State<AutoNilamDashboard> createState() => _AutoNilamDashboardState();
}

class _AutoNilamDashboardState extends State<AutoNilamDashboard> {
  bool _processingState = false;
  String? _extractedResultText;

  Future<void> _handleFileSelectionPipeline() async {
    FilePickerResult? selectedFileResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (selectedFileResult != null &&
        selectedFileResult.files.first.bytes != null) {
      setState(() {
        _processingState = true;
        _extractedResultText = null;
      });

      try {
        var multiPartNetworkRequest = http.MultipartRequest('POST',
            Uri.parse('https://autonilam-project.onrender.com/api/v1/analyze'));

        multiPartNetworkRequest.headers.addAll({
          "Accept": "application/json",
          "Access-Control-Allow-Origin": "*",
        });

        multiPartNetworkRequest.files.add(http.MultipartFile.fromBytes(
            'file', selectedFileResult.files.first.bytes!,
            filename: selectedFileResult.files.first.name));

        var networkStreamResponse = await multiPartNetworkRequest.send();
        var immediateResponseContent =
            await http.Response.fromStream(networkStreamResponse);

        if (immediateResponseContent.statusCode == 200) {
          final decodedJsonMap = json.decode(immediateResponseContent.body);
          setState(() {
            _extractedResultText = decodedJsonMap['result'];
            _processingState = false;
          });
        } else {
          throw Exception(
              "Server Error Code: ${immediateResponseContent.statusCode}\nDetails: ${immediateResponseContent.body}");
        }
      } catch (networkAnomalyError) {
        setState(() => _processingState = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Error encountered: ${networkAnomalyError.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('AutoNILAM Reader Portal',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          maxWidth: 600,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
            ],
          ),
          child: _processingState
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                        "Reading book structural text and generating ulasan..."),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("AutoNILAM Rumusan Engine",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    const Text(
                        "Upload your book or reading image snapshot to see its metadata and summary instantly."),
                    const Divider(height: 32),
                    if (_extractedResultText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Text(
                          _extractedResultText!,
                          style: const TextStyle(
                              fontSize: 15,
                              fontFamily: 'monospace',
                              height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    ElevatedButton.icon(
                      onPressed: _handleFileSelectionPipeline,
                      icon: const Icon(Icons.upload_file, color: Colors.white),
                      label: Text(
                          _extractedResultText == null
                              ? 'Upload File (PDF / Image)'
                              : 'Upload Another File',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
