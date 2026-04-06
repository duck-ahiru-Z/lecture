import 'package:flutter/material.dart';

// ======== 📦 データモデル ========
class LectureRecord {
  String id;
  String path;
  DateTime date;
  String subjectName;
  int lectureNumber;
  String? summaryText;

  LectureRecord({
    required this.id, required this.path, required this.date,
    required this.subjectName, required this.lectureNumber, this.summaryText,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'path': path, 'date': date.toIso8601String(),
    'subjectName': subjectName, 'lectureNumber': lectureNumber, 'summaryText': summaryText,
  };

  factory LectureRecord.fromJson(Map<String, dynamic> json) => LectureRecord(
    id: json['id'], path: json['path'], date: DateTime.parse(json['date']),
    subjectName: json['subjectName'], lectureNumber: json['lectureNumber'], summaryText: json['summaryText'],
  );
}

class TimetableEntry {
  String subjectName;
  int weekday;
  int period;
  int colorValue;

  TimetableEntry({required this.subjectName, required this.weekday, required this.period, required this.colorValue});
  Map<String, dynamic> toJson() => {'subjectName': subjectName, 'weekday': weekday, 'period': period, 'colorValue': colorValue};
  factory TimetableEntry.fromJson(Map<String, dynamic> json) => TimetableEntry(
    subjectName: json['subjectName'], weekday: json['weekday'], period: json['period'], colorValue: json['colorValue'] ?? Colors.blue.shade100.value,
  );
}

class PeriodTime {
  int startH, startM, endH, endM;
  PeriodTime(this.startH, this.startM, this.endH, this.endM);
  Map<String, dynamic> toJson() => {'startH': startH, 'startM': startM, 'endH': endH, 'endM': endM};
  factory PeriodTime.fromJson(Map<String, dynamic> json) => PeriodTime(json['startH'], json['startM'], json['endH'], json['endM']);
}

// アプリ全体で共有する時間割の初期設定
int globalMaxPeriods = 6;
Map<int, PeriodTime> globalCollegePeriods = {
  1: PeriodTime(9, 0, 10, 30), 2: PeriodTime(10, 40, 12, 10),
  3: PeriodTime(13, 0, 14, 30), 4: PeriodTime(14, 40, 16, 10),
  5: PeriodTime(16, 20, 17, 50), 6: PeriodTime(18, 0, 19, 30),
};