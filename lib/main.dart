import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 👇 さっき作った3つのファイルを読み込む！
import 'env.dart';
import 'models.dart';
import 'summary_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '講義ハック',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;

  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDuration = 0;
  Timer? _timer;

  List<LectureRecord> _records = [];
  List<TimetableEntry> _timetable = [];

  bool _isPlaying = false;
  String? _playingPath;
  
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackRate = 1.0; 
  bool _isLooping = false; 

  String _selectedFilter = 'すべて';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();

    _audioPlayer.onDurationChanged.listen((Duration d) => setState(() => _totalDuration = d));
    _audioPlayer.onPositionChanged.listen((Duration p) => setState(() => _currentPosition = p));
    _audioPlayer.onPlayerComplete.listen((_) => setState(() { 
      if (!_isLooping) {
        _isPlaying = false; 
        _playingPath = null;
        _currentPosition = Duration.zero;
      }
    }));

    _loadData(); 
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    globalMaxPeriods = prefs.getInt('maxPeriods') ?? 6;
    final periodsJson = prefs.getString('collegePeriods');
    if (periodsJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(periodsJson);
      globalCollegePeriods = decoded.map((key, value) => MapEntry(int.parse(key), PeriodTime.fromJson(value)));
    }
    try {
      final recordsJson = prefs.getStringList('records') ?? [];
      _records = recordsJson.map((e) => LectureRecord.fromJson(jsonDecode(e))).toList();
    } catch (e) { _records = []; }
    try {
      final timetableJson = prefs.getStringList('timetable') ?? [];
      _timetable = timetableJson.map((e) => TimetableEntry.fromJson(jsonDecode(e))).toList();
    } catch (e) { _timetable = []; }
    setState(() {});
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('records', _records.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> _saveTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('timetable', _timetable.map((e) => jsonEncode(e.toJson())).toList());
  }

  String _getCurrentSubject() {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    for (var entry in _timetable) {
      if (entry.weekday == now.weekday) {
        final periodTime = globalCollegePeriods[entry.period];
        if (periodTime != null) {
          final startMins = periodTime.startH * 60 + periodTime.startM;
          final endMins = periodTime.endH * 60 + periodTime.endM;
          if (nowMinutes >= startMins && nowMinutes <= endMins) return entry.subjectName;
        }
      }
    }
    return 'その他（自動判定外）';
  }

  int _calculateLectureNumber(String subjectName, DateTime newDate) {
    if (subjectName == 'その他（自動判定外）') return 1;
    final pastRecords = _records.where((r) => r.subjectName == subjectName).toList()..sort((a, b) => a.date.compareTo(b.date));
    int currentNumber = 1;
    DateTime? lastDate;
    for (var record in pastRecords) {
      if (lastDate == null) {
        lastDate = record.date;
      } else {
        if (!(record.date.year == lastDate.year && record.date.month == lastDate.month && record.date.day == lastDate.day)) {
          currentNumber++;
          lastDate = record.date;
        }
      }
    }
    if (pastRecords.isNotEmpty) {
      final latest = pastRecords.last.date;
      if (!(newDate.year == latest.year && newDate.month == latest.month && newDate.day == latest.day)) currentNumber++;
    }
    return currentNumber;
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/lecture_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
        setState(() { _isRecording = true; _isPaused = false; _recordDuration = 0; });
        _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => setState(() => _recordDuration++));
      }
    } catch (e) { debugPrint('録音エラー: $e'); }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    _timer?.cancel();
    setState(() { _isRecording = false; _isPaused = false; });

    if (path != null) {
      final now = DateTime.now();
      final autoSubject = _getCurrentSubject();
      setState(() {
        _records.insert(0, LectureRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(), path: path, date: now,
          subjectName: autoSubject, lectureNumber: _calculateLectureNumber(autoSubject, now),
        ));
      });
      await _saveRecords();
      setState(() { _currentIndex = 1; });
    }
  }

  Future<void> _togglePlay(String path) async {
    if (_playingPath == path) {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.resume();
        setState(() => _isPlaying = true);
      }
    } else {
      await _audioPlayer.stop();
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      
      await _audioPlayer.setPlaybackRate(_playbackRate);
      await _audioPlayer.setReleaseMode(_isLooping ? ReleaseMode.loop : ReleaseMode.stop); 
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() { _isPlaying = true; _playingPath = path; });
    }
  }

  Future<void> _seekAudio(int secondsToAdd) async {
    if (_playingPath == null) return;
    int newPositionSec = _currentPosition.inSeconds + secondsToAdd;
    if (newPositionSec < 0) newPositionSec = 0;
    if (newPositionSec > _totalDuration.inSeconds) newPositionSec = _totalDuration.inSeconds;
    await _audioPlayer.seek(Duration(seconds: newPositionSec));
  }

  Future<void> _changePlaybackRate(double rate) async {
    double newRate = rate.clamp(0.5, 3.0);
    newRate = double.parse(newRate.toStringAsFixed(1)); 
    setState(() => _playbackRate = newRate);
    if (_isPlaying) await _audioPlayer.setPlaybackRate(newRate);
  }

  Future<void> _toggleLoop() async {
    setState(() { _isLooping = !_isLooping; });
    await _audioPlayer.setReleaseMode(_isLooping ? ReleaseMode.loop : ReleaseMode.stop);
  }

  String _formatDurationText(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  Future<void> _deleteRecord(LectureRecord record) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認', style: TextStyle(color: Colors.red)),
        content: Text('「${record.subjectName} 第${record.lectureNumber}回」を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try { final file = File(record.path); if (await file.exists()) await file.delete(); } catch (e) { }
              setState(() {
                _records.removeWhere((r) => r.id == record.id);
                if (_playingPath == record.path) { _audioPlayer.stop(); _isPlaying = false; _playingPath = null; }
              });
              await _saveRecords();
              Navigator.pop(context); 
            },
            child: const Text('削除する'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(LectureRecord record) async {
    TextEditingController subCtrl = TextEditingController(text: record.subjectName);
    TextEditingController numCtrl = TextEditingController(text: record.lectureNumber.toString());
    final registeredSubjects = _timetable.map((e) => e.subjectName).toSet().toList();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('情報の編集'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (registeredSubjects.isNotEmpty) ...[
                const Text('時間割から選択', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 4,
                  children: registeredSubjects.map((sub) => ActionChip(label: Text(sub), backgroundColor: Colors.deepPurple.shade50, onPressed: () => subCtrl.text = sub)).toList(),
                ),
                const Divider(height: 24),
              ],
              TextField(controller: subCtrl, decoration: const InputDecoration(labelText: '科目名 (手動入力)')),
              TextField(controller: numCtrl, decoration: const InputDecoration(labelText: '第〇回'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              setState(() { record.subjectName = subCtrl.text.trim(); record.lectureNumber = int.tryParse(numCtrl.text) ?? record.lectureNumber; });
              await _saveRecords();
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.push_pin, color: Colors.deepPurple, size: 18),
                const SizedBox(width: 8),
                Text('自動判定: ${_getCurrentSubject()}', style: const TextStyle(fontSize: 16, color: Colors.deepPurple, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(
            _isRecording ? (_isPaused ? '⏸️ 一時停止中' : '🔴 録音中...') : '待機中',
            style: TextStyle(color: _isRecording ? Colors.red : Colors.grey, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text('${(_recordDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordDuration % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w200)),
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isRecording)
                SizedBox(
                  width: 100, height: 100,
                  child: FloatingActionButton(
                    onPressed: _startRecording, backgroundColor: Colors.redAccent, elevation: 4,
                    shape: const CircleBorder(), child: const Icon(Icons.mic, color: Colors.white, size: 50),
                  ),
                )
              else ...[
                SizedBox(
                  width: 80, height: 80,
                  child: FloatingActionButton(
                    onPressed: _isPaused ? () async { await _audioRecorder.resume(); setState(() => _isPaused = false); } 
                                         : () async { await _audioRecorder.pause(); setState(() => _isPaused = true); },
                    backgroundColor: Colors.orange, elevation: 4, shape: const CircleBorder(),
                    child: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(width: 40),
                SizedBox(
                  width: 80, height: 80,
                  child: FloatingActionButton(
                    onPressed: _stopRecording, backgroundColor: Colors.black87, elevation: 4, shape: const CircleBorder(),
                    child: const Icon(Icons.stop, color: Colors.white, size: 40),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final filteredRecords = _records.where((r) {
      final matchFilter = _selectedFilter == 'すべて' || r.subjectName == _selectedFilter;
      final matchQuery = _searchQuery.isEmpty || 
          r.subjectName.contains(_searchQuery) || 
          (r.summaryText != null && r.summaryText!.contains(_searchQuery));
      return matchFilter && matchQuery;
    }).toList();

    final subjectNames = ['すべて', ..._records.map((r) => r.subjectName).toSet()];

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'キーワードで要約を検索...',
              prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
              filled: true, fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              const Icon(Icons.filter_list, color: Colors.deepPurple), const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true, underline: const SizedBox(),
                  value: subjectNames.contains(_selectedFilter) ? _selectedFilter : 'すべて',
                  items: subjectNames.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                  onChanged: (v) => setState(() => _selectedFilter = v!),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredRecords.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('該当するデータがありません', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: filteredRecords.length,
                itemBuilder: (context, index) {
                  final record = filteredRecords[index];
                  final isThisSelected = _playingPath == record.path;
                  final hasSummary = record.summaryText != null;

                  return Card(
                    elevation: isThisSelected ? 4 : 0,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), 
                      side: BorderSide(color: isThisSelected ? Colors.deepPurple.shade300 : Colors.grey.shade200, width: isThisSelected ? 2 : 1)
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(color: Colors.deepPurple.shade50, shape: BoxShape.circle),
                                child: IconButton(
                                  icon: const Icon(Icons.audio_file, color: Colors.deepPurple, size: 28),
                                  onPressed: () => _togglePlay(record.path),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${record.subjectName} 第${record.lectureNumber}回', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text('${record.date.month}/${record.date.day} ${record.date.hour}:${record.date.minute.toString().padLeft(2, '0')} 録音', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          if (isThisSelected) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatDurationText(_currentPosition), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                                        Text(_formatDurationText(_totalDuration), style: const TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: Colors.deepPurple, inactiveTrackColor: Colors.deepPurple.shade100,
                                      thumbColor: Colors.deepPurple, trackHeight: 4.0,
                                    ),
                                    child: Slider(
                                      min: 0.0,
                                      max: _totalDuration.inSeconds > 0 ? _totalDuration.inSeconds.toDouble() : 1.0,
                                      value: _currentPosition.inSeconds.toDouble().clamp(0.0, _totalDuration.inSeconds > 0 ? _totalDuration.inSeconds.toDouble() : 1.0),
                                      onChanged: (value) async {
                                        await _audioPlayer.seek(Duration(seconds: value.toInt()));
                                      },
                                    ),
                                  ),
                                  
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: Icon(_isLooping ? Icons.repeat_one : Icons.repeat, color: _isLooping ? Colors.deepPurple : Colors.grey, size: 28),
                                        onPressed: _toggleLoop,
                                        tooltip: 'ループ再生',
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.replay_10, size: 36, color: Colors.black87),
                                        onPressed: () => _seekAudio(-10),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        decoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                                        child: IconButton(
                                          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
                                          onPressed: () => _togglePlay(record.path),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.forward_10, size: 36, color: Colors.black87),
                                        onPressed: () => _seekAudio(10),
                                      ),
                                      const SizedBox(width: 36), 
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange), onPressed: () => _changePlaybackRate(_playbackRate - 0.1)),
                                              SizedBox(width: 40, child: Text('${_playbackRate.toStringAsFixed(1)}x', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                              IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.orange), onPressed: () => _changePlaybackRate(_playbackRate + 0.1)),
                                            ],
                                          ),
                                          const SizedBox(width: 16),
                                          Row(
                                            children: [
                                              TextButton(onPressed: () => _changePlaybackRate(1.0), style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 6)), child: const Text('1.0x')),
                                              TextButton(onPressed: () => _changePlaybackRate(1.5), style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 6)), child: const Text('1.5x')),
                                              TextButton(onPressed: () => _changePlaybackRate(2.0), style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 6)), child: const Text('2.0x')),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider()),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.grey), tooltip: '編集', onPressed: () => _showEditDialog(record)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), tooltip: '削除', onPressed: () => _deleteRecord(record)),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasSummary ? Colors.deepPurple.shade50 : Colors.deepPurple,
                                  foregroundColor: hasSummary ? Colors.deepPurple : Colors.white, elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => SummaryScreen(
                                      record: record, 
                                      onSummarySaved: () async { await _saveRecords(); setState(() {}); },
                                    ),
                                  ));
                                },
                                icon: Icon(hasSummary ? Icons.visibility : Icons.auto_awesome, size: 18),
                                label: Text(hasSummary ? '要約を読む' : 'AIで要約'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildTimetableTab() {
    final List<String> weekdays = ['月', '火', '水', '木', '金'];
    final List<Color> colorPalette = [
      Colors.red.shade100, Colors.blue.shade100, Colors.green.shade100, Colors.orange.shade100, 
      Colors.purple.shade100, Colors.yellow.shade100, Colors.teal.shade100, Colors.pink.shade100,
    ];

    TimetableEntry? getEntryFor(int weekday, int period) {
      try { return _timetable.firstWhere((e) => e.weekday == weekday && e.period == period); } catch (e) { return null; }
    }

    Future<void> showEditCellDialog(int weekday, int period, TimetableEntry? entry) async {
      TextEditingController controller = TextEditingController(text: entry?.subjectName);
      int selectedColorValue = entry?.colorValue ?? colorPalette[1].value;

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: Text('${weekdays[weekday - 1]}曜 $period限'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: controller, decoration: const InputDecoration(hintText: '科目名 (空で削除)'), autofocus: true),
                const SizedBox(height: 20),
                const Text('背景色を選択', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: colorPalette.map((color) => GestureDetector(
                    onTap: () => setStateDialog(() => selectedColorValue = color.value),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: selectedColorValue == color.value ? Colors.black : Colors.transparent, width: 3)),
                    ),
                  )).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _timetable.removeWhere((e) => e.weekday == weekday && e.period == period);
                    if (controller.text.trim().isNotEmpty) {
                      _timetable.add(TimetableEntry(subjectName: controller.text.trim(), weekday: weekday, period: period, colorValue: selectedColorValue));
                    }
                  });
                  await _saveTimetable();
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> showSettingsDialog() async {
      int tempMaxPeriods = globalMaxPeriods;
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('時間割の設定'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('最大時限数:'),
                      DropdownButton<int>(
                        value: tempMaxPeriods,
                        items: [4, 5, 6, 7, 8].map((e) => DropdownMenuItem(value: e, child: Text('$e限'))).toList(),
                        onChanged: (v) => setStateDialog(() => tempMaxPeriods = v!),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true, itemCount: tempMaxPeriods,
                      itemBuilder: (context, index) {
                        int p = index + 1;
                        PeriodTime pt = globalCollegePeriods[p] ?? PeriodTime(9, 0, 10, 30);
                        return ListTile(
                          title: Text('$p限', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${pt.startH}:${pt.startM.toString().padLeft(2,'0')} 〜 ${pt.endH}:${pt.endM.toString().padLeft(2,'0')}'),
                          trailing: const Icon(Icons.edit, size: 16),
                          onTap: () async {
                            final start = await showTimePicker(context: context, initialTime: TimeOfDay(hour: pt.startH, minute: pt.startM));
                            if (start == null) return;
                            final end = await showTimePicker(context: context, initialTime: TimeOfDay(hour: pt.endH, minute: pt.endM));
                            if (end == null) return;
                            setStateDialog(() { globalCollegePeriods[p] = PeriodTime(start.hour, start.minute, end.hour, end.minute); });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
              ElevatedButton(
                onPressed: () async {
                  setState(() => globalMaxPeriods = tempMaxPeriods);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('maxPeriods', globalMaxPeriods);
                  await prefs.setString('collegePeriods', jsonEncode(globalCollegePeriods.map((k, v) => MapEntry(k.toString(), v.toJson()))));
                  Navigator.pop(context); 
                },
                child: const Text('保存して反映'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('時間割', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.settings, color: Colors.grey), tooltip: '設定', onPressed: showSettingsDialog)],
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 1, borderRadius: BorderRadius.circular(8)),
            columnWidths: const { 0: FixedColumnWidth(40) },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: [
                  const SizedBox(),
                  ...weekdays.map((day) => Padding(padding: const EdgeInsets.all(8.0), child: Center(child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold))))),
                ],
              ),
              for (int period = 1; period <= globalMaxPeriods; period++)
                TableRow(
                  children: [
                    TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Center(child: Text('$period', style: const TextStyle(fontWeight: FontWeight.bold)))),
                    for (int weekday = 1; weekday <= 5; weekday++)
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: InkWell(
                          onTap: () => showEditCellDialog(weekday, period, getEntryFor(weekday, period)),
                          child: Container(
                            height: 80, padding: const EdgeInsets.all(4),
                            color: getEntryFor(weekday, period) != null ? Color(getEntryFor(weekday, period)!.colorValue) : Colors.white,
                            child: Center(
                              child: Text(getEntryFor(weekday, period)?.subjectName ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = '講義ハック';
    if (_currentIndex == 0) appBarTitle = '講義の録音';
    if (_currentIndex == 1) appBarTitle = '講義ノート履歴';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _currentIndex != 2 ? AppBar(
        title: Text(appBarTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0,
      ) : null,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildRecordTab(),
          _buildHistoryTab(),
          _buildTimetableTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: '録音'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: '履歴'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_on), label: '時間割'),
        ],
      ),
    );
  }
}