import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ======== 🌍 言語管理システム (22言語対応) ========
final ValueNotifier<String> appLocale = ValueNotifier<String>('ja');

Future<void> loadSavedLocale() async {
  final prefs = await SharedPreferences.getInstance();
  appLocale.value = prefs.getString('app_lang') ?? 'ja';
}

Future<void> changeLocale(String langCode) async {
  appLocale.value = langCode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('app_lang', langCode);
}

const Map<String, String> supportedLanguages = {
  'en': 'English', 'ja': '日本語', 'de': 'Deutsch', 'fr': 'Français', 'es': 'Español',
  'ko': '한국어', 'zh': '繁體中文', 'pt': 'Português', 'hi': 'हिन्दी', 'ru': 'Русский',
  'it': 'Italiano', 'nl': 'Nederlands', 'sv': 'Svenska', 'no': 'Norsk', 'da': 'Dansk',
  'id': 'Bahasa Indonesia', 'th': 'ไทย', 'vi': 'Tiếng Việt', 'ar': 'العربية', 'he': 'עברית',
  'tr': 'Türkçe', 'pl': 'Polski'
};

String tr(String key) {
  final lang = appLocale.value;
  return _dictionary[key]?[lang] ?? _dictionary[key]?['en'] ?? key;
}

const Map<String, Map<String, String>> _dictionary = {
  'app_title': {
    'en': 'Lecture Hack', 'ja': '講義ハック', 'de': 'Vorlesung Hack', 'fr': 'Conférence Hack', 
    'es': 'Hack de Clase', 'ko': '강의 해크', 'zh': '講義Hack', 'pt': 'Hack de Palestra',
    'ru': 'Лекция Хак', 'it': 'Lezione Hack', 'th': 'เลคเชอร์แฮ็ค', 'ar': 'اختراق المحاضرات'
  },
  'tab_record': {
    'en': 'Record', 'ja': '録音', 'de': 'Aufnehmen', 'fr': 'Enregistrer', 'es': 'Grabar',
    'ko': '녹음', 'zh': '錄音', 'pt': 'Gravar', 'ru': 'Запись', 'id': 'Rekam', 'th': 'บันทึก',
    'it': 'Registra', 'nl': 'Opnemen', 'sv': 'Spela in', 'no': 'Ta opp', 'da': 'Optag',
    'vi': 'Ghi âm', 'ar': 'تسجيل', 'he': 'הקלט', 'tr': 'Kayıt', 'pl': 'Nagrywać', 'hi': 'रिकॉर्ड'
  },
  'tab_history': {
    'en': 'History', 'ja': '履歴', 'de': 'Verlauf', 'fr': 'Historique', 'es': 'Historial',
    'ko': '기록', 'zh': '歷史', 'pt': 'Histórico', 'ru': 'История', 'id': 'Riwayat', 'th': 'ประวัติ',
    'it': 'Cronologia', 'nl': 'Geschiedenis', 'sv': 'Historik', 'no': 'Historikk', 'da': 'Historik',
    'vi': 'Lịch sử', 'ar': 'سجل', 'he': 'היסטוריה', 'tr': 'Geçmiş', 'pl': 'Historia', 'hi': 'इतिहास'
  },
  'tab_timetable': {
    'en': 'Timetable', 'ja': '時間割', 'de': 'Stundenplan', 'fr': 'Emploi du temps', 'es': 'Horario',
    'ko': '시간표', 'zh': '時間表', 'pt': 'Horário', 'ru': 'Расписание', 'id': 'Jadwal', 'th': 'ตารางเรียน',
    'it': 'Orario', 'nl': 'Rooster', 'sv': 'Schema', 'no': 'Timeplan', 'da': 'Skema',
    'vi': 'Thời khóa biểu', 'ar': 'جدول', 'he': 'מערכת שעות', 'tr': 'Zaman Çizelgesi', 'pl': 'Plan zajęć', 'hi': 'समय सारणी'
  },
  'status_auto_subject': {
    'en': 'Auto: ', 'ja': '自動判定: ', 'de': 'Auto: ', 'fr': 'Auto: ', 'es': 'Auto: ',
    'ko': '자동: ', 'zh': '自動: ', 'pt': 'Auto: ', 'ru': 'Авто: ', 'th': 'อัตโนมัติ: ', 'ar': 'تلقائي: '
  },
  'status_recording': {
    'en': '🔴 Recording...', 'ja': '🔴 録音中...', 'de': '🔴 Aufnahme...', 'fr': '🔴 Enregistrement...',
    'es': '🔴 Grabando...', 'ko': '🔴 녹음 중...', 'zh': '🔴 錄音中...', 'pt': '🔴 Gravando...',
    'ru': '🔴 Запись...', 'it': '🔴 Registrazione...', 'th': '🔴 กำลังบันทึก...', 'ar': '🔴 جارٍ التسجيل...'
  },
  'status_paused': {
    'en': '⏸️ Paused', 'ja': '⏸️ 一時停止中', 'de': '⏸️ Pausiert', 'fr': '⏸️ En pause', 'es': '⏸️ Pausado',
    'ko': '⏸️ 일시 정지', 'zh': '⏸️ 已暫停', 'pt': '⏸️ Pausado', 'ru': '⏸️ Пауза', 'th': '⏸️ หยุดชั่วคราว', 'ar': '⏸️ متوقف مؤقتًا'
  },
  'status_standby': {
    'en': 'Standby', 'ja': '待機中', 'de': 'Bereit', 'fr': 'En attente', 'es': 'En espera',
    'ko': '대기 중', 'zh': '待機中', 'pt': 'Em espera', 'ru': 'В ожидании', 'it': 'In attesa', 'th': 'เตรียมพร้อม', 'ar': 'استعداد'
  },
  'search_hint': {
    'en': 'Search summaries...', 'ja': 'キーワードで要約を検索...', 'de': 'Zusammenfassungen suchen...',
    'fr': 'Rechercher...', 'es': 'Buscar resúmenes...', 'ko': '요약 검색...', 'zh': '搜尋摘要...',
    'pt': 'Pesquisar resumos...', 'ru': 'Поиск резюме...', 'th': 'ค้นหาสรุป...'
  },
  'filter_all': {
    'en': 'All', 'ja': 'すべて', 'de': 'Alle', 'fr': 'Tout', 'es': 'Todo',
    'ko': '전체', 'zh': '全部', 'pt': 'Todos', 'ru': 'Все', 'id': 'Semua', 'th': 'ทั้งหมด',
    'it': 'Tutti', 'nl': 'Alles', 'sv': 'Alla', 'no': 'Alle', 'da': 'Alle', 'vi': 'Tất cả', 'ar': 'الكل', 'he': 'הכל'
  },
  'btn_ai_summary': {
    'en': 'AI Summary', 'ja': 'AIで要約', 'de': 'KI-Zusammenfassung', 'fr': 'Résumé IA',
    'es': 'Resumen de IA', 'ko': 'AI 요약', 'zh': 'AI摘要', 'pt': 'Resumo por IA', 'ru': 'ИИ Резюме',
    'it': 'Riassunto IA', 'th': 'สรุปด้วย AI', 'ar': 'ملخص الذكاء الاصطناعي'
  },
  'btn_read_summary': {
    'en': 'Read Summary', 'ja': '要約を読む', 'de': 'Lesen', 'fr': 'Lire', 'es': 'Leer Resumen',
    'ko': '요약 읽기', 'zh': '閱讀摘要', 'pt': 'Ler Resumo', 'ru': 'Читать', 'id': 'Baca',
    'it': 'Leggi', 'th': 'อ่านสรุป', 'ar': 'اقرأ الملخص'
  },
  'no_data': {
    'en': 'No data available', 'ja': '該当するデータがありません', 'de': 'Keine Daten', 'fr': 'Aucune donnée',
    'es': 'Sin datos', 'ko': '데이터가 없습니다', 'zh': '沒有資料', 'pt': 'Sem dados', 'ru': 'Нет данных', 'th': 'ไม่มีข้อมูล'
  },
  'dialog_delete_title': {
    'en': 'Confirm Deletion', 'ja': '削除の確認', 'de': 'Löschen bestätigen', 'fr': 'Confirmer la suppression',
    'es': 'Confirmar eliminación', 'ko': '삭제 확인', 'zh': '確認刪除'
  },
  'dialog_delete_msg': {
    'en': 'Delete this record?', 'ja': 'この録音を削除しますか？', 'de': 'Diesen Eintrag löschen?',
    'fr': 'Supprimer cet enregistrement?', 'es': '¿Eliminar este registro?', 'ko': '이 기록을 삭제하시겠습니까?', 'zh': '刪除此記錄？'
  },
  'btn_cancel': {
    'en': 'Cancel', 'ja': 'キャンセル', 'de': 'Abbrechen', 'fr': 'Annuler', 'es': 'Cancelar',
    'ko': '취소', 'zh': '取消', 'pt': 'Cancelar', 'ru': 'Отмена', 'th': 'ยกเลิก'
  },
  'btn_delete': {
    'en': 'Delete', 'ja': '削除', 'de': 'Löschen', 'fr': 'Supprimer', 'es': 'Eliminar',
    'ko': '삭제', 'zh': '刪除', 'pt': 'Excluir', 'ru': 'Удалить', 'th': 'ลบ'
  },
  'btn_edit': {
    'en': 'Edit', 'ja': '編集', 'de': 'Bearbeiten', 'fr': 'Modifier', 'es': 'Editar',
    'ko': '편집', 'zh': '編輯', 'pt': 'Editar', 'ru': 'Изменить', 'th': 'แก้ไข'
  },
  'btn_save': {
    'en': 'Save', 'ja': '保存', 'de': 'Speichern', 'fr': 'Enregistrer', 'es': 'Guardar',
    'ko': '저장', 'zh': '保存', 'pt': 'Salvar', 'ru': 'Сохранить', 'th': 'บันทึก'
  },
  'subject_other': {
    'en': 'Other', 'ja': 'その他', 'de': 'Andere', 'fr': 'Autre', 'es': 'Otro',
    'ko': '기타', 'zh': '其他', 'pt': 'Outro', 'ru': 'Другое', 'th': 'อื่นๆ'
  },
  'setting_title': {'en': 'Timetable Settings', 'ja': '時間割の設定'},
  'setting_max_period': {'en': 'Max Periods:', 'ja': '最大時限数:'},
  'vol': {'en': 'Vol.', 'ja': '第'}
};