import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class Recording {
  final String name;
  final String path;
  final DateTime createdAt;

  Recording({
    required this.name,
    required this.path,
    required this.createdAt,
  });

  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
}

class AudioRecorder {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  String? _recordingPath;
  List<Recording> _recordings = [];
  bool _isPlaying = false;
  String? _currentPlayingPath;

  List<Recording> get recordings => _recordings;
  bool get isPlaying => _isPlaying;
  String? get currentPlayingPath => _currentPlayingPath;

  Future<void> initialize() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    
    try {
      await _recorder!.openRecorder();
      await _player!.openPlayer();
      _isRecorderInitialized = true;
      _isPlayerInitialized = true;
      
      // Kayıtları yükle
      await loadRecordings();
    } catch (e) {
      print('Ses kaydedici başlatılırken hata: $e');
    }
  }

  // Ses kaydını başlatmak için metot
  Future<bool> startRecording() async {
    if (!_isRecorderInitialized || _recorder == null) return false;
    
    try {
      // Kayıt için dosya yolu oluştur (Downloads klasöründe)
      Directory? downloadsDir = await getExternalStorageDirectory();
      if (downloadsDir != null) {
        // Downloads klasörünü oluştur
        Directory recordingsDir = Directory('${downloadsDir.path}/SesKayitlari');
        if (!await recordingsDir.exists()) {
          await recordingsDir.create(recursive: true);
        }
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        _recordingPath = '${recordingsDir.path}/recording_$timestamp.aac';
      } else {
        // Fallback: uygulama dizini
        Directory appDocDir = await getApplicationDocumentsDirectory();
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        _recordingPath = '${appDocDir.path}/recording_$timestamp.aac';
      }
      
      await _recorder!.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacADTS,
      );
      
      return true;
    } catch (e) {
      print('Kayıt başlatılırken hata: $e');
      return false;
    }
  }

  // Ses kaydını durdurmak için metot
  Future<bool> stopRecording() async {
    if (!_isRecorderInitialized || _recorder == null) return false;
    
    try {
      await _recorder!.stopRecorder();
      
      if (_recordingPath != null) {
        // Kayıt listesine ekle
        File file = File(_recordingPath!);
        if (await file.exists()) {
          String fileName = _recordingPath!.split('/').last;
          DateTime createdAt = DateTime.now();
          
          Recording recording = Recording(
            name: fileName,
            path: _recordingPath!,
            createdAt: createdAt,
          );
          
          _recordings.add(recording);
          _recordingPath = null;
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Kayıt durdurulurken hata: $e');
      return false;
    }
  }

  // Kayıtlı dosyaları listele
  Future<void> loadRecordings() async {
    try {
      _recordings.clear();
      
      // Önce harici depolamayı kontrol et
      Directory? downloadsDir = await getExternalStorageDirectory();
      if (downloadsDir != null) {
        Directory recordingsDir = Directory('${downloadsDir.path}/SesKayitlari');
        if (await recordingsDir.exists()) {
          List<FileSystemEntity> files = recordingsDir.listSync();
          
          for (FileSystemEntity file in files) {
            if (file is File && file.path.endsWith('.aac')) {
              String fileName = file.path.split('/').last;
              DateTime createdAt = await file.lastModified();
              
              Recording recording = Recording(
                name: fileName,
                path: file.path,
                createdAt: createdAt,
              );
              
              _recordings.add(recording);
            }
          }
        }
      }
      
      // Fallback: uygulama dizinindeki dosyaları da kontrol et
      Directory appDocDir = await getApplicationDocumentsDirectory();
      List<FileSystemEntity> appFiles = appDocDir.listSync();
      
      for (FileSystemEntity file in appFiles) {
        if (file is File && file.path.endsWith('.aac')) {
          String fileName = file.path.split('/').last;
          DateTime createdAt = await file.lastModified();
          
          Recording recording = Recording(
            name: fileName,
            path: file.path,
            createdAt: createdAt,
          );
          
          _recordings.add(recording);
        }
      }
      
      // Tarihe göre sırala (yeni kayıtlar üstte)
      _recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('Kayıtlar yüklenirken hata: $e');
    }
  }

  // Ses dosyasını çal
  Future<void> playRecording(Recording recording) async {
    if (!_isPlayerInitialized || _player == null) return;
    
    try {
      // Eğer aynı dosya çalıyorsa durdur
      if (_isPlaying && _currentPlayingPath == recording.path) {
        await _player!.stopPlayer();
        _isPlaying = false;
        _currentPlayingPath = null;
        return;
      }
      
      // Eğer başka bir dosya çalıyorsa durdur
      if (_player!.isPlaying) {
        await _player!.stopPlayer();
      }
      
      await _player!.startPlayer(
        fromURI: recording.path,
        codec: Codec.aacADTS,
      );
      
      _isPlaying = true;
      _currentPlayingPath = recording.path;
    } catch (e) {
      print('Ses çalarken hata: $e');
      _isPlaying = false;
      _currentPlayingPath = null;
    }
  }

  // Dosyayı sil
  Future<bool> deleteRecording(Recording recording) async {
    try {
      File file = File(recording.path);
      if (await file.exists()) {
        await file.delete();
        _recordings.remove(recording);
        return true;
      }
      return false;
    } catch (e) {
      print('Dosya silinirken hata: $e');
      return false;
    }
  }

  void dispose() {
    if (_isRecorderInitialized) {
      _recorder?.closeRecorder();
    }
    if (_isPlayerInitialized) {
      _player?.closePlayer();
    }
  }
}
