import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';    // 📤 テキストのシェア用に追加
import 'package:flutter/services.dart';         // 📋 コピー機能(Clipboard)用に追加

import 'models.dart'; 
import 'env.dart';    

// ======== 📖 要約を読む専用スクリーン ========
class SummaryScreen extends StatefulWidget {
  final LectureRecord record;
  final VoidCallback onSummarySaved;

  const SummaryScreen({super.key, required this.record, required this.onSummarySaved});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _isLoading = false;
  String _statusText = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.record.summaryText == null) {
      _generateSummary();
    }
  }

  Future<void> _generateSummary() async {
    setState(() { _isLoading = true; _statusText = '1/2: 音声をサーバーへアップロード中...'; });
    try {
      final file = File(widget.record.path);
      final bytes = await file.readAsBytes();
      final url = Uri.parse('https://generativelanguage.googleapis.com/upload/v1beta/files?key=$geminiApiKey');
      final request = http.Request('POST', url)
        ..headers.addAll({'X-Goog-Upload-Protocol': 'raw', 'X-Goog-Upload-Command': 'start, upload, finalize', 'X-Goog-Upload-Header-Content-Length': bytes.length.toString(), 'X-Goog-Upload-Header-Content-Type': 'audio/mp4', 'Content-Type': 'audio/mp4'})
        ..bodyBytes = bytes;

      final uploadRes = await request.send();
      final uploadBody = await uploadRes.stream.bytesToString();
      if (uploadRes.statusCode != 200) throw Exception('アップロード失敗');
      final fileUri = jsonDecode(uploadBody)['file']['uri'];

      setState(() => _statusText = '2/2: 優秀なTAがノートを作成中...\n(90分の講義だと少し時間がかかります)');
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: geminiApiKey);
      
      final prompt = '''
あなたは優秀な大学のティーチングアシスタント（TA）です。
提供される大学の講義データ（音声データ、または文字起こしテキスト）を深く解析し、学生の学習理解と成績向上を最大限サポートするための詳細なノートを作成してください。

【重要】
最初の挨拶や最後の締めの言葉など、AIとしての会話的な応答は一切含めないでください。
以下のフォーマットに沿った内容のみを、Markdown形式で直接出力してください。

## 1. 講義の要約（サマリー）
- 今回の講義の全体的なテーマと、結論や最も重要なメッセージを簡潔にまとめてください。

## 2. 重要なキーワードと解説
- 講義内で新しく登場した専門用語や、教員が強調していた重要な単語をピックアップし解説してください。

## 3. テスト対策・試験に関する重要情報
- 「テストに出るかもしれない」など教員が強調していた箇所を詳細にリストアップしてください。

## 4. 課題・提出物・事務連絡
- レポート、小テスト、次回までの宿題などの提出物がある場合、以下の項目を明確に書き出してください。
  - 課題の内容：
  - 提出期限：
  - 提出方法：
  - 形式や条件：
- 該当する内容が一切なかった場合は、「今回の講義では明言されていません」と記載してください。

## 5. 次回への準備・推奨文献（アクションアイテム）
- 次回の講義までに予習しておくべき範囲や参考図書をまとめてください。

## 6. 要確認事項・質疑応答
- 講義中に行われた質疑応答や、注意喚起として記載すべき事項をまとめてください。
''';

      final response = await model.generateContent([Content.multi([TextPart(prompt), FilePart(Uri.parse(fileUri))])]);
      
      setState(() { 
        widget.record.summaryText = response.text; 
        _isLoading = false; 
      });
      widget.onSummarySaved();

    } catch (e) {
      setState(() { _errorMessage = 'エラーが発生しました。\n$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('${widget.record.subjectName} 第${widget.record.lectureNumber}回', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.deepPurple),
        actions: [
          // 🌟 📋 コピーボタンを追加
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.deepPurple),
            tooltip: 'ノートをコピー',
            onPressed: () async {
              if (widget.record.summaryText != null) {
                await Clipboard.setData(ClipboardData(text: widget.record.summaryText!));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('要約をクリップボードにコピーしました！'), backgroundColor: Colors.deepPurple),
                  );
                }
              }
            },
          ),
          // 🌟 💬 シェアボタンを追加
          IconButton(
            icon: const Icon(Icons.ios_share, color: Colors.deepPurple),
            tooltip: 'ノートを共有',
            onPressed: () {
              if (widget.record.summaryText != null) {
                Share.share(
                  '【${widget.record.subjectName} 第${widget.record.lectureNumber}回 講義ノート】\n\n${widget.record.summaryText!}\n\n---\n※「講義ハック」アプリでAIが自動生成しました',
                  subject: '${widget.record.subjectName}のノート',
                );
              }
            },
          ),
          const SizedBox(width: 8), 
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(_statusText, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5, color: Colors.deepPurple)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))))
              : Column(
                  children: [
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.deepPurple.shade100, width: 2)),
                        child: Markdown(
                          data: widget.record.summaryText ?? '',
                          selectable: true,
                          padding: const EdgeInsets.all(24),
                          styleSheet: MarkdownStyleSheet(
                            h2: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: Colors.deepPurple),
                            p: const TextStyle(fontSize: 16, height: 1.8),
                            listBullet: const TextStyle(fontSize: 16, color: Colors.deepPurple),
                            blockquoteDecoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: Colors.deepPurple, width: 4))),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}