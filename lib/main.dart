import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'recorder.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ses Kaydedici',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  
  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    // Mikrofon izni al
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mikrofon izni gerekli!')),
      );
      return;
    }
    
    await _recorder.initialize();
    setState(() {});
  }

  Future<void> _startRecording() async {
    if (await _recorder.startRecording()) {
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _stopRecording() async {
    if (await _recorder.stopRecording()) {
      setState(() {
        _isRecording = false;
      });
      // Kayıt listesini yenile
      await _recorder.loadRecordings();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ses Kaydedici'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Kayıt butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isRecording ? null : _startRecording,
                  icon: Icon(Icons.mic),
                  label: Text('Kaydı Başlat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isRecording ? _stopRecording : null,
                  icon: Icon(Icons.stop),
                  label: Text('Kaydı Durdur'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Kayıt durumu göstergesi
            if (_isRecording)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.radio_button_checked, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Kayıt devam ediyor...', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            
            SizedBox(height: 20),
            
            // Kayıt listesi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kayıtlar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: _recorder.recordings.isEmpty
                        ? Center(
                            child: Text(
                              'Henüz kayıt yok',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _recorder.recordings.length,
                            itemBuilder: (context, index) {
                              final recording = _recorder.recordings[index];
                              return Card(
                                child: ListTile(
                                  leading: Icon(Icons.audiotrack),
                                  title: Text(recording.name),
                                  subtitle: Text(recording.formattedDate),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(_recorder.isPlaying && _recorder.currentPlayingPath == recording.path 
                                            ? Icons.pause 
                                            : Icons.play_arrow),
                                        onPressed: () async {
                                          await _recorder.playRecording(recording);
                                          setState(() {});
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete),
                                        onPressed: () async {
                                          await _recorder.deleteRecording(recording);
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
