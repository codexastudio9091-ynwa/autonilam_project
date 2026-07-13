import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'web_communication_stub.dart'
    if (dart.library.html) 'web_communication_real.dart';

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
  Map<String, dynamic>? _extractedMetaDataModel;

  Future<void> _handleFileSelectionPipeline() async {
    FilePickerResult? selectedFileResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (selectedFileResult != null &&
        selectedFileResult.files.first.bytes != null) {
      setState(() => _processingState = true);

      try {
        // Points to local server during testing phase; updates to your cloud instance endpoint later
        var multiPartNetworkRequest = http.MultipartRequest(
            'POST', Uri.parse('http://localhost:8000/api/v1/analyze'));

        multiPartNetworkRequest.files.add(http.MultipartFile.fromBytes(
            'file', selectedFileResult.files.first.bytes!,
            filename: selectedFileResult.files.first.name));

        var networkStreamResponse = await multiPartNetworkRequest.send();
        var immediateResponseContent =
            await http.Response.fromStream(networkStreamResponse);

        if (immediateResponseContent.statusCode == 200) {
          setState(() {
            _extractedMetaDataModel =
                json.decode(immediateResponseContent.body);
            _processingState = false;
          });
        } else {
          throw Exception(
              "Server rejected upload with code: ${immediateResponseContent.statusCode}");
        }
      } catch (networkAnomalyError) {
        setState(() => _processingState = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${networkAnomalyError.toString()}')));
      }
    }
  }

  void _triggerPlatformSyncRoutine() {
    if (_extractedMetaDataModel == null) return;

    // Stringify execution payloads securely out onto Javascript execution windows
    final transitPayloadString = json.encode({
      'source': 'AUTONILAM_FLUTTER_WEB',
      'payload': _extractedMetaDataModel
    });

    // Invoke our conditional compiler web messaging broker injection
    dispatchMessageToWindow(transitPayloadString);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Data sent! Login to DELIMa; Extension will autofill the form.'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('AutoNILAM Parent Portal',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: 600,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5))
            ],
          ),
          child: _processingState
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2563EB)),
                    SizedBox(height: 16),
                    Text("AI is reading book structure & generating ulasan...",
                        style: TextStyle(color: Color(0xFF64748B))),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_extractedMetaDataModel == null) ...[
                      const Icon(Icons.cloud_upload_outlined,
                          size: 64, color: Color(0xFF3B82F6)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _handleFileSelectionPipeline,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Select Child\'s PDF Book',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ] else ...[
                      const Text("Verified AI Extraction Results",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B))),
                      const Divider(height: 24),
                      Text("Tajuk: ${_extractedMetaDataModel!['title']}",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text("Penulis: ${_extractedMetaDataModel!['author']}"),
                      Text(
                          "Penerbit: ${_extractedMetaDataModel!['publisher']}"),
                      Text(
                          "Kategori: ${_extractedMetaDataModel!['isFiction'] ? 'Fiksyen' : 'Bukan Fiksyen'}"),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(
                            "Ulasan (NILAM Summary):\n${_extractedMetaDataModel!['ulasan']}",
                            style:
                                const TextStyle(fontStyle: FontStyle.italic)),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _triggerPlatformSyncRoutine,
                        icon: const Icon(Icons.flash_on, color: Colors.white),
                        label: const Text('Autofill AINS Record Form',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _extractedMetaDataModel = null),
                        child: const Text("Upload another book"),
                      )
                    ]
                  ],
                ),
        ),
      ),
    );
  }
}
