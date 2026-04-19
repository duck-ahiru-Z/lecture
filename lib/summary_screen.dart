import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';    // 📤 テキストのシェア用
import 'package:flutter/services.dart';         // 📋 コピー機能用

import 'models.dart'; 
import 'env.dart';    
import 'l10n.dart'; // 🌍 言語システムをインポート

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
    setState(() { _isLoading = true; _statusText = '1/2: Uploading...'; });
    try {
      final file = File(widget.record.path);
      final bytes = await file.readAsBytes();
      final url = Uri.parse('https://generativelanguage.googleapis.com/upload/v1beta/files?key=$geminiApiKey');
      final request = http.Request('POST', url)
        ..headers.addAll({'X-Goog-Upload-Protocol': 'raw', 'X-Goog-Upload-Command': 'start, upload, finalize', 'X-Goog-Upload-Header-Content-Length': bytes.length.toString(), 'X-Goog-Upload-Header-Content-Type': 'audio/mp4', 'Content-Type': 'audio/mp4'})
        ..bodyBytes = bytes;

      final uploadRes = await request.send();
      final uploadBody = await uploadRes.stream.bytesToString();
      if (uploadRes.statusCode != 200) throw Exception('Upload failed');
      final fileUri = jsonDecode(uploadBody)['file']['uri'];

      setState(() => _statusText = '2/2: AI is working...');
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: geminiApiKey);
      
      // 🌟 AIの出力言語を、ユーザーが選択している言語（アプリのUI言語）に合わせる設定
      final targetLanguage = supportedLanguages[appLocale.value] ?? 'English';

      final prompt = '''
あなたは優秀な大学のティーチングアシスタント（TA）です。
提供される大学の講義データ（音声データ、または文字起こしテキスト）を深く解析し、学生の学習理解と成績向上を最大限サポートするための詳細なノートを作成してください。

【重要】
最初の挨拶や最後の締めの言葉など、AIとしての会話的な応答は一切含めないでください。
以下のフォーマットに沿った内容のみを、Markdown形式で直接出力してください。
【超重要】
必ず「$targetLanguage」の言語に翻訳して出力してください。（例: If the target is English, write strictly in English. 如果是中文，請用中文輸出。）

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
      setState(() { _errorMessage = 'Error: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.record.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.deepPurple),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.deepPurple),
            onPressed: () async {
              if (widget.record.summaryText != null) {
                await Clipboard.setData(ClipboardData(text: widget.record.summaryText!));
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!'), backgroundColor: Colors.deepPurple));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.ios_share, color: Colors.deepPurple),
            onPressed: () {
              if (widget.record.summaryText != null) {
                Share.share('【${widget.record.subjectName}】\n\n${widget.record.summaryText!}\n\n---\nCreated by Lecture Hack AI');
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