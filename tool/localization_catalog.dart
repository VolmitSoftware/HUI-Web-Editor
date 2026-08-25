import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/config/field_docs.dart';
import 'package:gloss_editor/config/field_docs.g.dart';
import 'package:gloss_editor/config/gloss_json_schema.dart';
import 'package:gloss_editor/config/preview_templates.dart';
import 'package:gloss_editor/config/showcase_flavor.dart';
import 'package:gloss_editor/config/templates.dart';
import 'package:gloss_editor/logic/json_schema.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

import 'semantic_audit_glossary.dart';

const List<String> localizationLocaleCodes = <String>[
  'en_US',
  'de_DE',
  'es_ES',
  'fi_FI',
  'fr_FR',
  'he_IL',
  'it_IT',
  'ja-JP',
  'ko_KR',
  'lt_LT',
  'nl_NL',
  'pl_PL',
  'pt_PT',
  'ru_RU',
  'tr_TR',
  'vi_VI',
  'zh_CN',
  'zh_TW',
];

const Map<String, List<String>> localizationPluralForms =
    <String, List<String>>{
      'en_US': <String>['one', 'other'],
      'de_DE': <String>['one', 'other'],
      'es_ES': <String>['one', 'many', 'other'],
      'fi_FI': <String>['one', 'other'],
      'fr_FR': <String>['one', 'many', 'other'],
      'he_IL': <String>['one', 'two', 'other'],
      'it_IT': <String>['one', 'many', 'other'],
      'ja-JP': <String>['other'],
      'ko_KR': <String>['other'],
      'lt_LT': <String>['one', 'few', 'other'],
      'nl_NL': <String>['one', 'other'],
      'pl_PL': <String>['one', 'few', 'many', 'other'],
      'pt_PT': <String>['one', 'many', 'other'],
      'ru_RU': <String>['one', 'few', 'many', 'other'],
      'tr_TR': <String>['one', 'other'],
      'vi_VI': <String>['one', 'other'],
      'zh_CN': <String>['other'],
      'zh_TW': <String>['other'],
    };

const Map<String, Map<String, String>> _pitchGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{
        'field.pitch.sound': 'Tonhöhe',
        'field.pitch.orientation': 'Neigung',
      },
      'es_ES': <String, String>{
        'field.pitch.sound': 'Tono',
        'field.pitch.orientation': 'Inclinación',
      },
      'fi_FI': <String, String>{
        'field.pitch.sound': 'Sävelkorkeus',
        'field.pitch.orientation': 'Kallistus',
      },
      'fr_FR': <String, String>{
        'field.pitch.sound': 'Hauteur',
        'field.pitch.orientation': 'Inclinaison',
      },
      'he_IL': <String, String>{
        'field.pitch.sound': 'גובה צליל',
        'field.pitch.orientation': 'הטיה',
      },
      'it_IT': <String, String>{
        'field.pitch.sound': 'Tonalità',
        'field.pitch.orientation': 'Inclinazione',
      },
      'ja-JP': <String, String>{
        'field.pitch.sound': '音の高さ',
        'field.pitch.orientation': '傾き',
      },
      'ko_KR': <String, String>{
        'field.pitch.sound': '음높이',
        'field.pitch.orientation': '기울기',
      },
      'lt_LT': <String, String>{
        'field.pitch.sound': 'Garso aukštis',
        'field.pitch.orientation': 'Posvyris',
      },
      'nl_NL': <String, String>{
        'field.pitch.sound': 'Toonhoogte',
        'field.pitch.orientation': 'Kanteling',
      },
      'pl_PL': <String, String>{
        'field.pitch.sound': 'Wysokość dźwięku',
        'field.pitch.orientation': 'Nachylenie',
      },
      'pt_PT': <String, String>{
        'field.pitch.sound': 'Tom',
        'field.pitch.orientation': 'Inclinação',
      },
      'ru_RU': <String, String>{
        'field.pitch.sound': 'Высота звука',
        'field.pitch.orientation': 'Наклон',
      },
      'tr_TR': <String, String>{
        'field.pitch.sound': 'Ses perdesi',
        'field.pitch.orientation': 'Eğim',
      },
      'vi_VI': <String, String>{
        'field.pitch.sound': 'Cao độ',
        'field.pitch.orientation': 'Độ nghiêng',
      },
      'zh_CN': <String, String>{
        'field.pitch.sound': '音高',
        'field.pitch.orientation': '俯仰角',
      },
      'zh_TW': <String, String>{
        'field.pitch.sound': '音高',
        'field.pitch.orientation': '俯仰角',
      },
    };

const Map<String, Map<String, String>> _historyBooleanGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{
        'history.boolean.true': 'wahr',
        'history.boolean.false': 'falsch',
      },
      'es_ES': <String, String>{
        'history.boolean.true': 'verdadero',
        'history.boolean.false': 'falso',
      },
      'fi_FI': <String, String>{
        'history.boolean.true': 'tosi',
        'history.boolean.false': 'epätosi',
      },
      'fr_FR': <String, String>{
        'history.boolean.true': 'vrai',
        'history.boolean.false': 'faux',
      },
      'he_IL': <String, String>{
        'history.boolean.true': 'אמת',
        'history.boolean.false': 'שקר',
      },
      'it_IT': <String, String>{
        'history.boolean.true': 'vero',
        'history.boolean.false': 'falso',
      },
      'ja-JP': <String, String>{
        'history.boolean.true': '真',
        'history.boolean.false': '偽',
      },
      'ko_KR': <String, String>{
        'history.boolean.true': '참',
        'history.boolean.false': '거짓',
      },
      'lt_LT': <String, String>{
        'history.boolean.true': 'tiesa',
        'history.boolean.false': 'netiesa',
      },
      'nl_NL': <String, String>{
        'history.boolean.true': 'waar',
        'history.boolean.false': 'onwaar',
      },
      'pl_PL': <String, String>{
        'history.boolean.true': 'prawda',
        'history.boolean.false': 'fałsz',
      },
      'pt_PT': <String, String>{
        'history.boolean.true': 'verdadeiro',
        'history.boolean.false': 'falso',
      },
      'ru_RU': <String, String>{
        'history.boolean.true': 'истина',
        'history.boolean.false': 'ложь',
      },
      'tr_TR': <String, String>{
        'history.boolean.true': 'doğru',
        'history.boolean.false': 'yanlış',
      },
      'vi_VI': <String, String>{
        'history.boolean.true': 'đúng',
        'history.boolean.false': 'sai',
      },
      'zh_CN': <String, String>{
        'history.boolean.true': '真',
        'history.boolean.false': '假',
      },
      'zh_TW': <String, String>{
        'history.boolean.true': '真',
        'history.boolean.false': '假',
      },
    };

const Map<String, String> _animationPlayerSurfaceGlossary = <String, String>{
  'de_DE': 'Wiedergabe',
  'es_ES': 'Reproductor',
  'fi_FI': 'Soitin',
  'fr_FR': 'Lecteur',
  'he_IL': 'נגן',
  'it_IT': 'Lettore',
  'ja-JP': 'プレーヤー',
  'ko_KR': '플레이어',
  'lt_LT': 'Leistuvas',
  'nl_NL': 'Speler',
  'pl_PL': 'Odtwarzacz',
  'pt_PT': 'Leitor',
  'ru_RU': 'Проигрыватель',
  'tr_TR': 'Oynatıcı',
  'vi_VI': 'Trình phát',
  'zh_CN': '播放器',
  'zh_TW': '播放器',
};

const Map<String, Map<String, String>> _soundCategoryGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{
        'sound_category.master': 'Gesamtlautstärke',
        'sound_category.music': 'Musik',
        'sound_category.record': 'Musikblöcke',
        'sound_category.weather': 'Wetter',
        'sound_category.block': 'Blöcke',
        'sound_category.hostile': 'Feindliche Kreaturen',
        'sound_category.neutral': 'Freundliche Kreaturen',
        'sound_category.player': 'Spieler',
        'sound_category.ambient': 'Atmosphäre/Umgebung',
        'sound_category.voice': 'Sprachausgabe/Stimme',
      },
      'es_ES': <String, String>{
        'sound_category.master': 'Volumen general',
        'sound_category.music': 'Música',
        'sound_category.record': 'Bloques musicales',
        'sound_category.weather': 'Clima',
        'sound_category.block': 'Bloques',
        'sound_category.hostile': 'Criaturas hostiles',
        'sound_category.neutral': 'Criaturas pacíficas',
        'sound_category.player': 'Jugadores',
        'sound_category.ambient': 'Ambiente/Entorno',
        'sound_category.voice': 'Narrador/Voz',
      },
      'fi_FI': <String, String>{
        'sound_category.master': 'Kaikki äänet',
        'sound_category.music': 'Musiikki',
        'sound_category.record': 'Levysoitin/Sointukuutiot',
        'sound_category.weather': 'Sää',
        'sound_category.block': 'Kuutiot',
        'sound_category.hostile': 'Vihamieliset olennot',
        'sound_category.neutral': 'Ystävälliset olennot',
        'sound_category.player': 'Pelaajat',
        'sound_category.ambient': 'Tunnelma/Ympäristö',
        'sound_category.voice': 'Lukija/Ääni',
      },
      'fr_FR': <String, String>{
        'sound_category.master': 'Volume principal',
        'sound_category.music': 'Musique',
        'sound_category.record': 'Blocs musicaux',
        'sound_category.weather': 'Météo',
        'sound_category.block': 'Blocs',
        'sound_category.hostile': 'Créatures hostiles',
        'sound_category.neutral': 'Créatures passives',
        'sound_category.player': 'Joueurs',
        'sound_category.ambient': 'Environnement',
        'sound_category.voice': 'Narrateur',
      },
      'he_IL': <String, String>{
        'sound_category.master': 'עוצמה ראשית',
        'sound_category.music': 'מוזיקה',
        'sound_category.record': 'תיבת נגינה/תיבת צליל',
        'sound_category.weather': 'מזג אוויר',
        'sound_category.block': 'בלוקים',
        'sound_category.hostile': 'יצורים עוינים',
        'sound_category.neutral': 'יצורים ידידותיים',
        'sound_category.player': 'שחקנים',
        'sound_category.ambient': 'אווירה/סביבה',
        'sound_category.voice': 'קריינות/דיבור',
      },
      'it_IT': <String, String>{
        'sound_category.master': 'Volume generale',
        'sound_category.music': 'Musica',
        'sound_category.record': 'Blocchi musicali',
        'sound_category.weather': 'Tempo atmosferico',
        'sound_category.block': 'Blocchi',
        'sound_category.hostile': 'Creature ostili',
        'sound_category.neutral': 'Creature pacifiche',
        'sound_category.player': 'Giocatori',
        'sound_category.ambient': 'Ambiente',
        'sound_category.voice': 'Assistente vocale',
      },
      'ja-JP': <String, String>{
        'sound_category.master': '主音量',
        'sound_category.music': 'BGM',
        'sound_category.record': 'ジュークボックス／音符ブロック',
        'sound_category.weather': '天候',
        'sound_category.block': 'ブロック',
        'sound_category.hostile': '敵対的Mob',
        'sound_category.neutral': '友好的Mob',
        'sound_category.player': 'プレイヤー',
        'sound_category.ambient': '環境音',
        'sound_category.voice': '音声読み上げ／声',
      },
      'ko_KR': <String, String>{
        'sound_category.master': '전체 음량',
        'sound_category.music': '음악',
        'sound_category.record': '주크박스/소리 블록',
        'sound_category.weather': '날씨',
        'sound_category.block': '블록',
        'sound_category.hostile': '적대적 몹',
        'sound_category.neutral': '친화적 몹',
        'sound_category.player': '플레이어',
        'sound_category.ambient': '분위기/환경',
        'sound_category.voice': '내레이터/음성',
      },
      'lt_LT': <String, String>{
        'sound_category.master': 'Garso stiprumas',
        'sound_category.music': 'Muzika',
        'sound_category.record': 'Grotuvai/natų blokai',
        'sound_category.weather': 'Oras',
        'sound_category.block': 'Blokai',
        'sound_category.hostile': 'Priešiški padarai',
        'sound_category.neutral': 'Draugiški padarai',
        'sound_category.player': 'Žaidėjai',
        'sound_category.ambient': 'Fonas/aplinka',
        'sound_category.voice': 'Įgarsintojas/balsas',
      },
      'nl_NL': <String, String>{
        'sound_category.master': 'Hoofdvolume',
        'sound_category.music': 'Muziek',
        'sound_category.record': 'Platenspeler/nootblokken',
        'sound_category.weather': 'Weer',
        'sound_category.block': 'Blokken',
        'sound_category.hostile': 'Vijandige wezens',
        'sound_category.neutral': 'Vriendelijke wezens',
        'sound_category.player': 'Spelers',
        'sound_category.ambient': 'Omgeving',
        'sound_category.voice': 'Verteller/stem',
      },
      'pl_PL': <String, String>{
        'sound_category.master': 'Ogólny poziom głośności',
        'sound_category.music': 'Muzyka',
        'sound_category.record': 'Bloki dźwiękowe',
        'sound_category.weather': 'Pogoda',
        'sound_category.block': 'Bloki',
        'sound_category.hostile': 'Wrogie stworzenia',
        'sound_category.neutral': 'Przyjazne stworzenia',
        'sound_category.player': 'Gracze',
        'sound_category.ambient': 'Otoczenie/środowisko',
        'sound_category.voice': 'Narrator/Głos',
      },
      'pt_PT': <String, String>{
        'sound_category.master': 'Volume geral',
        'sound_category.music': 'Música',
        'sound_category.record': 'Blocos musicais',
        'sound_category.weather': 'Clima',
        'sound_category.block': 'Blocos',
        'sound_category.hostile': 'Criaturas hostis',
        'sound_category.neutral': 'Criaturas inofensivas',
        'sound_category.player': 'Jogadores',
        'sound_category.ambient': 'Ambiente',
        'sound_category.voice': 'Voz/Diálogos',
      },
      'ru_RU': <String, String>{
        'sound_category.master': 'Общая громкость',
        'sound_category.music': 'Музыка',
        'sound_category.record': 'Музыкальные блоки',
        'sound_category.weather': 'Погода',
        'sound_category.block': 'Блоки',
        'sound_category.hostile': 'Враждебные мобы',
        'sound_category.neutral': 'Мирные мобы',
        'sound_category.player': 'Игроки',
        'sound_category.ambient': 'Окружение',
        'sound_category.voice': 'Диктор/Голос',
      },
      'tr_TR': <String, String>{
        'sound_category.master': 'Ana Ses',
        'sound_category.music': 'Müzik',
        'sound_category.record': 'Müzik/Nota Bloğu',
        'sound_category.weather': 'Hava Durumu',
        'sound_category.block': 'Bloklar',
        'sound_category.hostile': 'Saldırgan Canlılar',
        'sound_category.neutral': 'Dost Canlılar',
        'sound_category.player': 'Oyuncular',
        'sound_category.ambient': 'Çevresel',
        'sound_category.voice': 'Metin Okuyucu/Konuşma',
      },
      'vi_VI': <String, String>{
        'sound_category.master': 'Âm lượng tổng',
        'sound_category.music': 'Âm nhạc',
        'sound_category.record': 'Khối phát nhạc',
        'sound_category.weather': 'Thời tiết',
        'sound_category.block': 'Khối',
        'sound_category.hostile': 'Sinh vật ác',
        'sound_category.neutral': 'Sinh vật lành',
        'sound_category.player': 'Người chơi',
        'sound_category.ambient': 'Môi trường',
        'sound_category.voice': 'Giọng nói',
      },
      'zh_CN': <String, String>{
        'sound_category.master': '主音量',
        'sound_category.music': '音乐',
        'sound_category.record': '唱片机/音符盒',
        'sound_category.weather': '天气',
        'sound_category.block': '方块',
        'sound_category.hostile': '敌对生物',
        'sound_category.neutral': '友好生物',
        'sound_category.player': '玩家',
        'sound_category.ambient': '环境',
        'sound_category.voice': '复述功能/语音',
      },
      'zh_TW': <String, String>{
        'sound_category.master': '主音量',
        'sound_category.music': '音樂',
        'sound_category.record': '唱片機／音階盒',
        'sound_category.weather': '天氣',
        'sound_category.block': '方塊',
        'sound_category.hostile': '敵對生物',
        'sound_category.neutral': '友好生物',
        'sound_category.player': '玩家',
        'sound_category.ambient': '環境音效／環境',
        'sound_category.voice': '朗讀功能／語音',
      },
    };

const Map<String, Map<String, String>> _centerGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{
        'billboard.center': 'Zum Betrachter',
        'alignment.center': 'Zentriert',
      },
      'es_ES': <String, String>{
        'billboard.center': 'Hacia el observador',
        'alignment.center': 'Centrado',
      },
      'fi_FI': <String, String>{
        'billboard.center': 'Katsojaa kohti',
        'alignment.center': 'Keskitetty',
      },
      'fr_FR': <String, String>{
        'billboard.center': 'Face au spectateur',
        'alignment.center': 'Centré',
      },
      'he_IL': <String, String>{
        'billboard.center': 'מול הצופה',
        'alignment.center': 'ממורכז',
      },
      'it_IT': <String, String>{
        'billboard.center': "Verso l'osservatore",
        'alignment.center': 'Centrato',
      },
      'ja-JP': <String, String>{
        'billboard.center': '視点に向く',
        'alignment.center': '中央揃え',
      },
      'ko_KR': <String, String>{
        'billboard.center': '보는 이를 향함',
        'alignment.center': '가운데 맞춤',
      },
      'lt_LT': <String, String>{
        'billboard.center': 'Į žiūrovą',
        'alignment.center': 'Centruota',
      },
      'nl_NL': <String, String>{
        'billboard.center': 'Naar de kijker',
        'alignment.center': 'Gecentreerd',
      },
      'pl_PL': <String, String>{
        'billboard.center': 'W stronę widza',
        'alignment.center': 'Wyśrodkowanie',
      },
      'pt_PT': <String, String>{
        'billboard.center': 'Virado para o observador',
        'alignment.center': 'Centrado',
      },
      'ru_RU': <String, String>{
        'billboard.center': 'К зрителю',
        'alignment.center': 'По центру',
      },
      'tr_TR': <String, String>{
        'billboard.center': 'İzleyiciye dönük',
        'alignment.center': 'Ortalanmış',
      },
      'vi_VI': <String, String>{
        'billboard.center': 'Hướng về người xem',
        'alignment.center': 'Căn giữa',
      },
      'zh_CN': <String, String>{
        'billboard.center': '面向观察者',
        'alignment.center': '居中',
      },
      'zh_TW': <String, String>{
        'billboard.center': '面向觀看者',
        'alignment.center': '置中',
      },
    };

const Map<String, Map<String, String>> _animationBlendGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{
        'animation_blend.add': 'Addition',
        'animation_blend.replace': 'Ersetzen',
        'animation_blend.multiply': 'Multiplikation',
      },
      'es_ES': <String, String>{
        'animation_blend.add': 'Suma',
        'animation_blend.replace': 'Sustitución',
        'animation_blend.multiply': 'Multiplicación',
      },
      'fi_FI': <String, String>{
        'animation_blend.add': 'Lisäys',
        'animation_blend.replace': 'Korvaus',
        'animation_blend.multiply': 'Kertolasku',
      },
      'fr_FR': <String, String>{
        'animation_blend.add': 'Addition',
        'animation_blend.replace': 'Remplacement',
        'animation_blend.multiply': 'Multiplication',
      },
      'he_IL': <String, String>{
        'animation_blend.add': 'חיבור',
        'animation_blend.replace': 'החלפה',
        'animation_blend.multiply': 'כפל',
      },
      'it_IT': <String, String>{
        'animation_blend.add': 'Addizione',
        'animation_blend.replace': 'Sostituzione',
        'animation_blend.multiply': 'Moltiplicazione',
      },
      'ja-JP': <String, String>{
        'animation_blend.add': '加算',
        'animation_blend.replace': '置換',
        'animation_blend.multiply': '乗算',
      },
      'ko_KR': <String, String>{
        'animation_blend.add': '더하기',
        'animation_blend.replace': '대체',
        'animation_blend.multiply': '곱하기',
      },
      'lt_LT': <String, String>{
        'animation_blend.add': 'Sudėtis',
        'animation_blend.replace': 'Pakeitimas',
        'animation_blend.multiply': 'Daugyba',
      },
      'nl_NL': <String, String>{
        'animation_blend.add': 'Optellen',
        'animation_blend.replace': 'Vervangen',
        'animation_blend.multiply': 'Vermenigvuldigen',
      },
      'pl_PL': <String, String>{
        'animation_blend.add': 'Dodawanie',
        'animation_blend.replace': 'Zastępowanie',
        'animation_blend.multiply': 'Mnożenie',
      },
      'pt_PT': <String, String>{
        'animation_blend.add': 'Adição',
        'animation_blend.replace': 'Substituição',
        'animation_blend.multiply': 'Multiplicação',
      },
      'ru_RU': <String, String>{
        'animation_blend.add': 'Сложение',
        'animation_blend.replace': 'Замена',
        'animation_blend.multiply': 'Умножение',
      },
      'tr_TR': <String, String>{
        'animation_blend.add': 'Ekleme',
        'animation_blend.replace': 'Değiştirme',
        'animation_blend.multiply': 'Çarpma',
      },
      'vi_VI': <String, String>{
        'animation_blend.add': 'Cộng',
        'animation_blend.replace': 'Thay thế',
        'animation_blend.multiply': 'Nhân',
      },
      'zh_CN': <String, String>{
        'animation_blend.add': '相加',
        'animation_blend.replace': '替换',
        'animation_blend.multiply': '相乘',
      },
      'zh_TW': <String, String>{
        'animation_blend.add': '相加',
        'animation_blend.replace': '取代',
        'animation_blend.multiply': '相乘',
      },
    };

const Map<String, List<String>> _skinHeadTranslationBans =
    <String, List<String>>{
      'de_DE': <String>['skinhead'],
      'fi_FI': <String>['nahkapää'],
      'he_IL': <String>['ראשי עור', 'ראש עור'],
      'ja-JP': <String>['スキンヘッド'],
      'zh_TW': <String>['進口皮頭', '皮膚頭'],
    };

const Map<String, List<String>> _customItemTranslationBans =
    <String, List<String>>{
      'de_DE': <String>['artikel', 'element'],
      'es_ES': <String>['artículo', 'elemento'],
      'fi_FI': <String>['tuote', 'nimike', 'kohde', 'alkio'],
      'fr_FR': <String>['article', 'élément'],
      'it_IT': <String>['articol', 'element'],
      'nl_NL': <String>['artikel', 'element'],
      'pt_PT': <String>['artigo'],
      'zh_TW': <String>['專案'],
    };

const Map<String, List<String>> _playerTranslationBans = <String, List<String>>{
  'es_ES': <String>['reproductor', 'reproductora'],
  'fi_FI': <String>['soitin', 'soittim'],
  'fr_FR': <String>['lecteur', 'lectrice'],
  'it_IT': <String>['lettore', 'lettrice'],
  'lt_LT': <String>['grotuv'],
  'pl_PL': <String>['odtwarzacz'],
  'he_IL': <String>['נגן'],
  'ja-JP': <String>['プレーヤー', '選手'],
  'ko_KR': <String>['선수'],
  'zh_CN': <String>['播放器', '球员'],
  'zh_TW': <String>['播放器', '球員'],
};

const Map<String, List<String>> _skinTranslationBans = <String, List<String>>{
  'es_ES': <String>['piel', 'máscara'],
  'fi_FI': <String>['iho', 'nahka'],
  'fr_FR': <String>['peau'],
  'it_IT': <String>['pelle'],
  'pt_PT': <String>['capa', 'pele'],
  'he_IL': <String>['עור'],
};

const Map<String, List<String>> _tickTranslationBans = <String, List<String>>{
  'de_DE': <String>['zeck', 'häkchen'],
  'es_ES': <String>['garrapat', 'marca de verificación'],
  'fi_FI': <String>['punk', 'valintamerk', 'rasti'],
  'fr_FR': <String>['tique', 'coch'],
  'he_IL': <String>['קרצי', 'סימונ', 'סמן'],
  'it_IT': <String>['zecc', 'spunta'],
  'ja-JP': <String>['チェックマーク', 'ダニ', 'カチカチ'],
  'ko_KR': <String>['선택', '진드기'],
  'lt_LT': <String>['erkė', 'varnel'],
  'nl_NL': <String>['teken', 'vink'],
  'pl_PL': <String>['kleszcz', 'znacznik', 'zaznacz'],
  'pt_PT': <String>['carraç', 'marcaç', 'marque'],
  'ru_RU': <String>['клещ', 'галоч'],
  'tr_TR': <String>['kene', 'onay işareti'],
  'vi_VI': <String>['bọ ve', 'dấu tích', 'đánh dấu'],
  'zh_CN': <String>['蜱', '勾选', '滴答', '滴答声', '刻度'],
  'zh_TW': <String>['蜱', '勾選', '滴答', '滴答聲', '刻度'],
};

const Map<String, List<String>> _pitchTranslationBans = <String, List<String>>{
  'he_IL': <String>['מגרש'],
};

const Map<String, List<String>> _hoverTranslationBans = <String, List<String>>{
  'de_DE': <String>['schweb'],
  'es_ES': <String>['flot'],
  'fi_FI': <String>['leiju'],
  'fr_FR': <String>['plané', 'flott'],
  'he_IL': <String>['ריחף'],
  'it_IT': <String>['alegg'],
  'ja-JP': <String>['ホバリングした'],
  'ko_KR': <String>['맴돌'],
  'lt_LT': <String>['sklandė'],
  'nl_NL': <String>['zweef'],
  'pl_PL': <String>['unosił'],
  'pt_PT': <String>['pairou'],
  'ru_RU': <String>['завис'],
  'tr_TR': <String>['havada asılı'],
  'vi_VI': <String>['lơ lửng'],
  'zh_CN': <String>['盘旋'],
  'zh_TW': <String>['盤旋'],
};

const Map<String, List<String>> _blockDistanceTranslationBans =
    <String, List<String>>{
      'de_DE': <String>['blockiert'],
      'es_ES': <String>['bloquea'],
      'fi_FI': <String>['estää'],
      'fr_FR': <String>['bloque '],
      'he_IL': <String>['חוסם', 'חסימות'],
      'it_IT': <String>['blocca'],
      'ja-JP': <String>['ブロックします'],
      'ko_KR': <String>['차단'],
      'lt_LT': <String>['blokuoja'],
      'nl_NL': <String>['blokkeert'],
      'pl_PL': <String>['blokuje'],
      'pt_PT': <String>['bloqueia'],
      'ru_RU': <String>['блокирует'],
      'tr_TR': <String>['engeller'],
      'vi_VI': <String>['chặn'],
      'zh_CN': <String>['阻止'],
      'zh_TW': <String>['阻止'],
    };

const Map<String, List<String>> _smeltTranslationBans = <String, List<String>>{
  'de_DE': <String>['riech'],
  'es_ES': <String>['oler'],
  'fi_FI': <String>['haist'],
  'fr_FR': <String>['sentir'],
  'it_IT': <String>['annus'],
  'nl_NL': <String>['ruik'],
  'pt_PT': <String>['cheir'],
};

const Map<String, List<String>> _brewTranslationBans = <String, List<String>>{
  'de_DE': <String>['kaffee', 'bier'],
  'es_ES': <String>['café', 'cerveza'],
  'fi_FI': <String>['kahv', 'olut'],
  'fr_FR': <String>['café', 'bière'],
  'it_IT': <String>['caffè', 'birra'],
  'nl_NL': <String>['koffie', 'bier'],
  'pt_PT': <String>['café', 'cerveja'],
};

const Map<String, String> _scoreboardGlossary = <String, String>{
  'de_DE': 'Scoreboard',
  'es_ES': 'Marcador',
  'fi_FI': 'Tulostaulu',
  'fr_FR': 'Scoreboard',
  'he_IL': 'לוח תוצאות',
  'it_IT': 'Scoreboard',
  'ja-JP': 'スコアボード',
  'ko_KR': '점수판',
  'lt_LT': 'Rezultatų lentelė',
  'nl_NL': 'Scorebord',
  'pl_PL': 'Tablica wyników',
  'pt_PT': 'Tabela de pontuação',
  'ru_RU': 'Таблица результатов',
  'tr_TR': 'Skor tablosu',
  'vi_VI': 'Bảng điểm',
  'zh_CN': '计分板',
  'zh_TW': '計分板',
};

const Map<String, String> _tablistGlossary = <String, String>{
  'de_DE': 'Tablist',
  'es_ES': 'Tablist',
  'fi_FI': 'Pelaajalista',
  'fr_FR': 'Tablist',
  'he_IL': 'רשימת שחקנים',
  'it_IT': 'Tablist',
  'ja-JP': 'タブリスト',
  'ko_KR': '플레이어 목록',
  'lt_LT': 'Žaidėjų sąrašas',
  'nl_NL': 'Tablist',
  'pl_PL': 'Lista graczy',
  'pt_PT': 'Tablist',
  'ru_RU': 'Список игроков',
  'tr_TR': 'Oyuncu listesi',
  'vi_VI': 'Danh sách người chơi',
  'zh_CN': '玩家列表',
  'zh_TW': '玩家列表',
};

const Map<String, String> _scoreboardLowerGlossary = <String, String>{
  'de_DE': 'Scoreboard',
  'es_ES': 'marcador',
  'fi_FI': 'tulostaulu',
  'fr_FR': 'scoreboard',
  'he_IL': 'לוח תוצאות',
  'it_IT': 'scoreboard',
  'ja-JP': 'スコアボード',
  'ko_KR': '점수판',
  'lt_LT': 'rezultatų lentelė',
  'nl_NL': 'scorebord',
  'pl_PL': 'tablica wyników',
  'pt_PT': 'tabela de pontuação',
  'ru_RU': 'таблица результатов',
  'tr_TR': 'skor tablosu',
  'vi_VI': 'bảng điểm',
  'zh_CN': '计分板',
  'zh_TW': '計分板',
};

const Map<String, String> _tablistLowerGlossary = <String, String>{
  'de_DE': 'Tablist',
  'es_ES': 'tablist',
  'fi_FI': 'pelaajalista',
  'fr_FR': 'tablist',
  'he_IL': 'רשימת שחקנים',
  'it_IT': 'tablist',
  'ja-JP': 'タブリスト',
  'ko_KR': '플레이어 목록',
  'lt_LT': 'žaidėjų sąrašas',
  'nl_NL': 'tablist',
  'pl_PL': 'lista graczy',
  'pt_PT': 'tablist',
  'ru_RU': 'список игроков',
  'tr_TR': 'oyuncu listesi',
  'vi_VI': 'danh sách người chơi',
  'zh_CN': '玩家列表',
  'zh_TW': '玩家列表',
};

const Map<String, String> _customItemGlossary = <String, String>{
  'de_DE': 'Benutzerdefinierter Gegenstand',
  'es_ES': 'Objeto personalizado',
  'fi_FI': 'Mukautettu esine',
  'fr_FR': 'Objet personnalisé',
  'he_IL': 'פריט מותאם אישית',
  'it_IT': 'Oggetto personalizzato',
  'ja-JP': 'カスタムアイテム',
  'ko_KR': '맞춤 아이템',
  'lt_LT': 'Pasirinktinis daiktas',
  'nl_NL': 'Aangepast voorwerp',
  'pl_PL': 'Niestandardowy przedmiot',
  'pt_PT': 'Item personalizado',
  'ru_RU': 'Пользовательский предмет',
  'tr_TR': 'Özel eşya',
  'vi_VI': 'Vật phẩm tùy chỉnh',
  'zh_CN': '自定义物品',
  'zh_TW': '自訂物品',
};

const Map<String, List<String>> _menuTranslationBans = <String, List<String>>{
  'nl_NL': <String>['menukaart'],
  'pt_PT': <String>['cardápio'],
};

const Map<String, List<String>> _panelTranslationBans = <String, List<String>>{
  'lt_LT': <String>['skydas'],
};

const Map<String, List<String>> _minecraftItemTranslationBans =
    <String, List<String>>{
      'de_DE': <String>['artikel', 'element'],
      'es_ES': <String>['artículo', 'elemento'],
      'fi_FI': <String>['tuote', 'kohde', 'nimike', 'alkio'],
      'fr_FR': <String>['article', 'élément'],
      'it_IT': <String>['articolo', 'elemento'],
      'ko_KR': <String>['품목', '항목'],
      'lt_LT': <String>['prekė', 'element'],
      'nl_NL': <String>['artikel'],
      'pt_PT': <String>['artigo'],
      'ru_RU': <String>['товар', 'элемент'],
      'tr_TR': <String>['öğe', 'ürün'],
      'vi_VI': <String>['mục', 'mặt hàng'],
      'zh_CN': <String>['项目', '商品'],
      'zh_TW': <String>['專案', '項目', '商品'],
      'pl_PL': <String>['element'],
    };

const Map<String, Set<String>> _minecraftItemDomainAllowlist =
    <String, Set<String>>{
      'vi_VI': <String>{
        'messages["Custom item catalog"]',
        'messages["Custom item catalog cleared."]',
        'messages["Import custom item catalog"]',
      },
    };

const Map<String, String> _itemGlossary = <String, String>{
  'de_DE': 'Gegenstand',
  'es_ES': 'Objeto',
  'fi_FI': 'Esine',
  'fr_FR': 'Objet',
  'he_IL': 'פריט',
  'it_IT': 'Oggetto',
  'ja-JP': 'アイテム',
  'ko_KR': '아이템',
  'lt_LT': 'Daiktas',
  'nl_NL': 'Voorwerp',
  'pl_PL': 'Przedmiot',
  'pt_PT': 'Item',
  'ru_RU': 'Предмет',
  'tr_TR': 'Eşya',
  'vi_VI': 'Vật phẩm',
  'zh_CN': '物品',
  'zh_TW': '物品',
};

const Map<String, Map<String, String>> _blockGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{
        'Block': 'Block',
        'Blocks': 'Blöcke',
        'blocks': 'Blöcke',
      },
      'es_ES': <String, String>{
        'Block': 'Bloque',
        'Blocks': 'Bloques',
        'blocks': 'bloques',
      },
      'fi_FI': <String, String>{
        'Block': 'Lohko',
        'Blocks': 'Lohkot',
        'blocks': 'lohkot',
      },
      'fr_FR': <String, String>{
        'Block': 'Bloc',
        'Blocks': 'Blocs',
        'blocks': 'blocs',
      },
      'he_IL': <String, String>{
        'Block': 'בלוק',
        'Blocks': 'בלוקים',
        'blocks': 'בלוקים',
      },
      'it_IT': <String, String>{
        'Block': 'Blocco',
        'Blocks': 'Blocchi',
        'blocks': 'blocchi',
      },
      'ja-JP': <String, String>{
        'Block': 'ブロック',
        'Blocks': 'ブロック',
        'blocks': 'ブロック',
      },
      'ko_KR': <String, String>{'Block': '블록', 'Blocks': '블록', 'blocks': '블록'},
      'lt_LT': <String, String>{
        'Block': 'Blokas',
        'Blocks': 'Blokai',
        'blocks': 'blokai',
      },
      'nl_NL': <String, String>{
        'Block': 'Blok',
        'Blocks': 'Blokken',
        'blocks': 'blokken',
      },
      'pl_PL': <String, String>{
        'Block': 'Blok',
        'Blocks': 'Bloki',
        'blocks': 'bloki',
      },
      'pt_PT': <String, String>{
        'Block': 'Bloco',
        'Blocks': 'Blocos',
        'blocks': 'blocos',
      },
      'ru_RU': <String, String>{
        'Block': 'Блок',
        'Blocks': 'Блоки',
        'blocks': 'блоки',
      },
      'tr_TR': <String, String>{
        'Block': 'Blok',
        'Blocks': 'Bloklar',
        'blocks': 'bloklar',
      },
      'vi_VI': <String, String>{
        'Block': 'Khối',
        'Blocks': 'Các khối',
        'blocks': 'các khối',
      },
      'zh_CN': <String, String>{'Block': '方块', 'Blocks': '方块', 'blocks': '方块'},
      'zh_TW': <String, String>{'Block': '方塊', 'Blocks': '方塊', 'blocks': '方塊'},
    };

const Map<String, Map<String, String>> _tickGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{'Tick': 'Tick', 'ticks': 'Ticks'},
      'es_ES': <String, String>{'Tick': 'Tick', 'ticks': 'ticks'},
      'fi_FI': <String, String>{'Tick': 'Pelitikki', 'ticks': 'pelitikit'},
      'fr_FR': <String, String>{'Tick': 'Tick', 'ticks': 'ticks'},
      'he_IL': <String, String>{'Tick': 'טיק', 'ticks': 'טיקים'},
      'it_IT': <String, String>{'Tick': 'Tick', 'ticks': 'tick'},
      'ja-JP': <String, String>{'Tick': 'ティック', 'ticks': 'ティック'},
      'ko_KR': <String, String>{'Tick': '틱', 'ticks': '틱'},
      'lt_LT': <String, String>{'Tick': 'Tiksas', 'ticks': 'tiksai'},
      'nl_NL': <String, String>{'Tick': 'Tick', 'ticks': 'ticks'},
      'pl_PL': <String, String>{'Tick': 'Tick', 'ticks': 'ticki'},
      'pt_PT': <String, String>{'Tick': 'Tick', 'ticks': 'ticks'},
      'ru_RU': <String, String>{'Tick': 'Тик', 'ticks': 'тики'},
      'tr_TR': <String, String>{'Tick': 'Tik', 'ticks': 'tikler'},
      'vi_VI': <String, String>{'Tick': 'Tick', 'ticks': 'tick'},
      'zh_CN': <String, String>{'Tick': '游戏刻', 'ticks': '游戏刻'},
      'zh_TW': <String, String>{'Tick': '遊戲刻', 'ticks': '遊戲刻'},
    };

const Map<String, String> _entryGlossary = <String, String>{
  'de_DE': 'Eintrag',
  'es_ES': 'Entrada',
  'fi_FI': 'Merkintä',
  'fr_FR': 'Entrée',
  'he_IL': 'רשומה',
  'it_IT': 'Voce',
  'ja-JP': '項目',
  'ko_KR': '항목',
  'lt_LT': 'Įrašas',
  'nl_NL': 'Vermelding',
  'pl_PL': 'Wpis',
  'pt_PT': 'Entrada',
  'ru_RU': 'Запись',
  'tr_TR': 'Kayıt',
  'vi_VI': 'Mục',
  'zh_CN': '条目',
  'zh_TW': '條目',
};

const Map<String, String> _entriesGlossary = <String, String>{
  'de_DE': 'Einträge',
  'es_ES': 'Entradas',
  'fi_FI': 'Merkinnät',
  'fr_FR': 'Entrées',
  'he_IL': 'רשומות',
  'it_IT': 'Voci',
  'ja-JP': '項目',
  'ko_KR': '항목',
  'lt_LT': 'Įrašai',
  'nl_NL': 'Vermeldingen',
  'pl_PL': 'Wpisy',
  'pt_PT': 'Entradas',
  'ru_RU': 'Записи',
  'tr_TR': 'Kayıtlar',
  'vi_VI': 'Các mục',
  'zh_CN': '条目',
  'zh_TW': '條目',
};

const Map<String, String> _closedGlossary = <String, String>{
  'de_DE': 'GESCHLOSSEN',
  'es_ES': 'CERRADO',
  'fi_FI': 'SULJETTU',
  'fr_FR': 'FERMÉ',
  'he_IL': 'סגור',
  'it_IT': 'CHIUSO',
  'ja-JP': '閉じています',
  'ko_KR': '닫힘',
  'lt_LT': 'UŽDARYTA',
  'nl_NL': 'GESLOTEN',
  'pl_PL': 'ZAMKNIĘTE',
  'pt_PT': 'FECHADO',
  'ru_RU': 'ЗАКРЫТО',
  'tr_TR': 'KAPALI',
  'vi_VI': 'ĐÃ ĐÓNG',
  'zh_CN': '已关闭',
  'zh_TW': '已關閉',
};

const Map<String, Map<String, String>> _previewSimMinecraftGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{
        'Furnace minecart': 'Antriebslore',
        'Hopper minecart': 'Trichterlore',
        'Music disc': 'Schallplatte',
      },
      'es_ES': <String, String>{
        'Furnace minecart': 'Vagoneta con horno',
        'Hopper minecart': 'Vagoneta con tolva',
        'Music disc': 'Disco de música',
      },
      'fi_FI': <String, String>{
        'Furnace minecart': 'Moottoroitu kaivosvaunu',
        'Hopper minecart': 'Suppilokaivosvaunu',
        'Music disc': 'Musiikkilevy',
      },
      'fr_FR': <String, String>{
        'Furnace minecart': 'Wagonnet motorisé',
        'Hopper minecart': 'Wagonnet à entonnoir',
        'Music disc': 'Disque',
      },
      'he_IL': <String, String>{
        'Furnace minecart': 'קרונית עם תנור',
        'Hopper minecart': 'קרונית עם משפך',
        'Music disc': 'דיסק מוזיקה',
      },
      'it_IT': <String, String>{
        'Furnace minecart': 'Vagonetto con fornace',
        'Hopper minecart': 'Vagonetto con tramoggia',
        'Music disc': 'Disco musicale',
      },
      'ja-JP': <String, String>{
        'Furnace minecart': 'かまど付きのトロッコ',
        'Hopper minecart': 'ホッパー付きのトロッコ',
        'Music disc': 'レコード',
      },
      'ko_KR': <String, String>{
        'Furnace minecart': '화로가 실린 광산 수레',
        'Hopper minecart': '호퍼가 실린 광산 수레',
        'Music disc': '음반',
      },
      'lt_LT': <String, String>{
        'Furnace minecart': 'Vagonėlis su krosnimi',
        'Hopper minecart': 'Vagonėlis su piltuvu',
        'Music disc': 'Muzikos diskas',
      },
      'nl_NL': <String, String>{
        'Furnace minecart': 'Mijnkar met oven',
        'Hopper minecart': 'Mijnkar met trechter',
        'Music disc': 'Muziekplaat',
      },
      'pl_PL': <String, String>{
        'Furnace minecart': 'Napędzany wagonik',
        'Hopper minecart': 'Wagonik z lejem',
        'Music disc': 'Płyta muzyczna',
      },
      'pt_PT': <String, String>{
        'Furnace minecart': 'Carrinho de Mina com Fornalha',
        'Hopper minecart': 'Carrinho de Mina com Funil',
        'Music disc': 'Disco de Música',
      },
      'ru_RU': <String, String>{
        'Furnace minecart': 'Самоходная вагонетка',
        'Hopper minecart': 'Загрузочная вагонетка',
        'Music disc': 'Пластинка',
      },
      'tr_TR': <String, String>{
        'Furnace minecart': 'Ocaklı Vagon',
        'Hopper minecart': 'Hunili Vagon',
        'Music disc': 'Müzik Diski',
      },
      'vi_VI': <String, String>{
        'Furnace minecart': 'Xe mỏ có lò nung',
        'Hopper minecart': 'Xe mỏ có phễu',
        'Music disc': 'Đĩa nhạc',
      },
      'zh_CN': <String, String>{
        'Furnace minecart': '动力矿车',
        'Hopper minecart': '漏斗矿车',
        'Music disc': '音乐唱片',
      },
      'zh_TW': <String, String>{
        'Furnace minecart': '熔爐礦車',
        'Hopper minecart': '漏斗礦車',
        'Music disc': '唱片',
      },
    };

const Map<String, String> _slotGlossary = <String, String>{
  'de_DE': 'Slot',
  'es_ES': 'Casilla',
  'fi_FI': 'Paikka',
  'fr_FR': 'Emplacement',
  'he_IL': 'משבצת',
  'it_IT': 'Slot',
  'ja-JP': 'スロット',
  'ko_KR': '슬롯',
  'lt_LT': 'Vieta',
  'nl_NL': 'Vak',
  'pl_PL': 'Miejsce',
  'pt_PT': 'Espaço',
};

const Map<String, String> _playerHeadGlossary = <String, String>{
  'de_DE': 'Spielerkopf',
  'es_ES': 'Cabeza de jugador',
  'fi_FI': 'Pelaajan pää',
  'fr_FR': 'Tête de joueur',
  'he_IL': 'ראש שחקן',
  'it_IT': 'Testa di giocatore',
  'ja-JP': 'プレイヤーの頭',
  'ko_KR': '플레이어 머리',
  'lt_LT': 'Žaidėjo galva',
  'nl_NL': 'Spelershoofd',
  'pl_PL': 'Głowa gracza',
  'pt_PT': 'Cabeça de Jogador',
  'ru_RU': 'Голова игрока',
  'tr_TR': 'Oyuncu Kafası',
  'vi_VI': 'Đầu người chơi',
  'zh_CN': '玩家头颅',
  'zh_TW': '玩家頭顱',
};

const Map<String, Map<String, String>> _shortUiLabelGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{
        'Push': 'Push',
        'Replace': 'Ersetzen',
        'Spawn': 'Erzeugen',
        'Permissions': 'Berechtigungen',
        'Radius': 'Radius',
        'Strength': 'Stärke',
        'Sky': 'Himmelslicht',
        'Decrease': 'Verringern',
        'Increase': 'Erhöhen',
        'View': 'Ansicht',
        'Item id': 'Gegenstands-ID',
      },
      'es_ES': <String, String>{
        'Push': 'Añadir',
        'Replace': 'Reemplazar',
        'Spawn': 'Generar',
        'Permissions': 'Permisos',
        'Radius': 'Radio',
        'Strength': 'Intensidad',
        'Sky': 'Luz del cielo',
        'Decrease': 'Disminuir',
        'Increase': 'Aumentar',
        'View': 'Vista',
        'Item id': 'ID del objeto',
      },
      'fi_FI': <String, String>{
        'Push': 'Lisää pinoon',
        'Replace': 'Korvaa',
        'Spawn': 'Luo',
        'Permissions': 'Oikeudet',
        'Radius': 'Säde',
        'Strength': 'Voimakkuus',
        'Sky': 'Taivaanvalo',
        'Decrease': 'Vähennä',
        'Increase': 'Lisää',
        'View': 'Näkymä',
        'Item id': 'Esineen tunnus',
        'Help': 'Ohje',
      },
      'fr_FR': <String, String>{
        'Push': 'Empiler',
        'Replace': 'Remplacer',
        'Spawn': 'Générer',
        'Permissions': 'Autorisations',
        'Radius': 'Rayon',
        'Strength': 'Intensité',
        'Sky': 'Lumière du ciel',
        'Decrease': 'Diminuer',
        'Increase': 'Augmenter',
        'View': 'Vue',
      },
      'he_IL': <String, String>{
        'Push': 'דחיפה',
        'Replace': 'החלפה',
        'Spawn': 'הופעה',
        'Radius': 'רדיוס',
        'Strength': 'עוצמה',
        'Sky': 'אור שמיים',
        'Decrease': 'הפחת',
        'Increase': 'הגדל',
        'View': 'תצוגה',
      },
      'it_IT': <String, String>{
        'Push': 'Aggiungi',
        'Replace': 'Sostituisci',
        'Spawn': 'Genera',
        'Permissions': 'Permessi',
        'Radius': 'Raggio',
        'Strength': 'Intensità',
        'Sky': 'Luce del cielo',
        'Decrease': 'Diminuisci',
        'Increase': 'Aumenta',
        'View': 'Vista',
        'Item id': 'ID oggetto',
        'File': 'File',
        'Browse items': 'Sfoglia oggetti',
        'Browse blocks': 'Sfoglia blocchi',
        'Default items': 'Oggetti predefiniti',
      },
      'ja-JP': <String, String>{
        'Push': 'プッシュ',
        'Replace': '置換',
        'Spawn': '出現',
        'Permissions': '権限',
        'Radius': '半径',
        'Strength': '強度',
        'Sky': '天空光',
        'Decrease': '減らす',
        'Increase': '増やす',
        'View': '表示',
      },
      'ko_KR': <String, String>{
        'Push': '푸시',
        'Replace': '교체',
        'Spawn': '생성',
        'Permissions': '권한',
        'Radius': '반경',
        'Strength': '강도',
        'Sky': '하늘빛',
        'Decrease': '줄이기',
        'Increase': '늘리기',
        'View': '보기',
      },
      'lt_LT': <String, String>{
        'Push': 'Stumti',
        'Replace': 'Pakeisti',
        'Spawn': 'Atsiradimas',
        'Sky': 'Dangaus šviesa',
        'Decrease': 'Sumažinti',
        'Increase': 'Padidinti',
        'View': 'Rodinys',
      },
      'nl_NL': <String, String>{
        'Push': 'Toevoegen',
        'Replace': 'Vervangen',
        'Spawn': 'Genereren',
        'Permissions': 'Rechten',
        'Radius': 'Straal',
        'Strength': 'Sterkte',
        'Sky': 'Hemellicht',
        'Decrease': 'Verlagen',
        'Increase': 'Verhogen',
        'View': 'Weergave',
        'Item id': 'Voorwerp-ID',
        'Browse items': 'Voorwerpen doorzoeken',
        'Browse blocks': 'Blokken doorzoeken',
        'Default items': 'Standaardvoorwerpen',
      },
      'pl_PL': <String, String>{
        'Push': 'Dodaj na stos',
        'Replace': 'Zastąp',
        'Spawn': 'Pojawienie się',
        'Sky': 'Światło nieba',
        'Decrease': 'Zmniejsz',
        'Increase': 'Zwiększ',
        'View': 'Widok',
      },
      'pt_PT': <String, String>{
        'Push': 'Adicionar',
        'Replace': 'Substituir',
        'Spawn': 'Gerar',
        'Permissions': 'Permissões',
        'Radius': 'Raio',
        'Strength': 'Intensidade',
        'Sky': 'Luz do céu',
        'Decrease': 'Diminuir',
        'Increase': 'Aumentar',
        'View': 'Vista',
        'Gloss Editor': 'Editor do Gloss',
        'Browse items': 'Procurar itens',
        'Browse blocks': 'Procurar blocos',
        'Default items': 'Itens predefinidos',
      },
      'ru_RU': <String, String>{
        'Push': 'Добавить',
        'Replace': 'Заменить',
        'Spawn': 'Создать',
        'Permissions': 'Разрешения',
        'Radius': 'Радиус',
        'Strength': 'Сила',
        'Sky': 'Небесный свет',
        'Decrease': 'Уменьшить',
        'Increase': 'Увеличить',
        'View': 'Вид',
        'Gloss Editor': 'Редактор Gloss',
        'Browse items': 'Просмотреть предметы',
        'Browse blocks': 'Просмотреть блоки',
        'Default items': 'Предметы по умолчанию',
      },
      'tr_TR': <String, String>{
        'Push': 'Ekle',
        'Replace': 'Değiştir',
        'Spawn': 'Oluştur',
        'Permissions': 'İzinler',
        'Radius': 'Yarıçap',
        'Strength': 'Güç',
        'Sky': 'Gökyüzü ışığı',
        'Decrease': 'Azalt',
        'Increase': 'Artır',
        'View': 'Görünüm',
        'Item id': 'Eşya kimliği',
        'Gloss Editor': 'Gloss Editörü',
        'Browse items': 'Eşyalara göz at',
        'Browse blocks': 'Bloklara göz at',
        'Default items': 'Varsayılan eşyalar',
      },
      'vi_VI': <String, String>{
        'Push': 'Đẩy vào',
        'Replace': 'Thay thế',
        'Spawn': 'Sinh ra',
        'Permissions': 'Quyền',
        'Radius': 'Bán kính',
        'Strength': 'Cường độ',
        'Sky': 'Ánh sáng bầu trời',
        'Decrease': 'Giảm',
        'Increase': 'Tăng',
        'View': 'Chế độ xem',
        'Item id': 'ID vật phẩm',
        'Gloss Editor': 'Trình chỉnh sửa Gloss',
        'Browse items': 'Duyệt vật phẩm',
        'Browse blocks': 'Duyệt khối',
        'Default items': 'Vật phẩm mặc định',
      },
      'zh_CN': <String, String>{
        'Push': '推入',
        'Replace': '替换',
        'Spawn': '生成',
        'Sky': '天空光照',
        'Decrease': '减小',
        'Increase': '增大',
        'View': '视图',
      },
      'zh_TW': <String, String>{
        'Push': '推入',
        'Replace': '取代',
        'Spawn': '生成',
        'Sky': '天空光照',
        'Decrease': '減少',
        'Increase': '增加',
        'View': '檢視',
      },
    };

const Map<String, Map<String, String>> _menuGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{'Menu': 'Menü', 'menu': 'Menü'},
      'es_ES': <String, String>{'Menu': 'Menú', 'menu': 'menú'},
      'fi_FI': <String, String>{'Menu': 'Valikko', 'menu': 'valikko'},
      'fr_FR': <String, String>{'Menu': 'Menu', 'menu': 'menu'},
      'he_IL': <String, String>{'Menu': 'תפריט', 'menu': 'תפריט'},
      'it_IT': <String, String>{'Menu': 'Menu', 'menu': 'menu'},
      'ja-JP': <String, String>{'Menu': 'メニュー', 'menu': 'メニュー'},
      'ko_KR': <String, String>{'Menu': '메뉴', 'menu': '메뉴'},
      'lt_LT': <String, String>{'Menu': 'Meniu', 'menu': 'meniu'},
      'nl_NL': <String, String>{'Menu': 'Menu', 'menu': 'menu'},
      'pl_PL': <String, String>{'Menu': 'Menu', 'menu': 'menu'},
      'pt_PT': <String, String>{'Menu': 'Menu', 'menu': 'menu'},
      'ru_RU': <String, String>{'Menu': 'Меню', 'menu': 'меню'},
      'tr_TR': <String, String>{'Menu': 'Menü', 'menu': 'menü'},
      'vi_VI': <String, String>{'Menu': 'Trình đơn', 'menu': 'trình đơn'},
      'zh_CN': <String, String>{'Menu': '菜单', 'menu': '菜单'},
      'zh_TW': <String, String>{'Menu': '選單', 'menu': '選單'},
    };

const Map<String, Map<String, String>> _panelGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{'Panel': 'Bedienfeld', 'panel': 'Bedienfeld'},
      'es_ES': <String, String>{'Panel': 'Panel', 'panel': 'panel'},
      'fi_FI': <String, String>{'Panel': 'Paneeli', 'panel': 'paneeli'},
      'fr_FR': <String, String>{'Panel': 'Panneau', 'panel': 'panneau'},
      'he_IL': <String, String>{'Panel': 'לוח', 'panel': 'לוח'},
      'it_IT': <String, String>{'Panel': 'Pannello', 'panel': 'pannello'},
      'ja-JP': <String, String>{'Panel': 'パネル', 'panel': 'パネル'},
      'ko_KR': <String, String>{'Panel': '패널', 'panel': '패널'},
      'lt_LT': <String, String>{'Panel': 'Skydelis', 'panel': 'skydelis'},
      'nl_NL': <String, String>{'Panel': 'Paneel', 'panel': 'paneel'},
      'pl_PL': <String, String>{'Panel': 'Panel', 'panel': 'panel'},
      'pt_PT': <String, String>{'Panel': 'Painel', 'panel': 'painel'},
      'ru_RU': <String, String>{'Panel': 'Панель', 'panel': 'панель'},
      'tr_TR': <String, String>{'Panel': 'Panel', 'panel': 'panel'},
      'vi_VI': <String, String>{
        'Panel': 'Bảng điều khiển',
        'panel': 'bảng điều khiển',
      },
      'zh_CN': <String, String>{'Panel': '面板', 'panel': '面板'},
      'zh_TW': <String, String>{'Panel': '面板', 'panel': '面板'},
    };

const Map<String, Map<String, String>> _ambiguousLabelGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{
        'Billboard': 'Ausrichtung',
        'Roll': 'Rollwinkel',
        'Yaw': 'Gierwinkel',
        'Scale': 'Skalierung',
        'Offset': 'Versatz',
        'Light': 'Hell',
        'Light level': 'Lichtstufe',
      },
      'es_ES': <String, String>{
        'Billboard': 'Orientación',
        'Roll': 'Alabeo',
        'Yaw': 'Rotación horizontal',
        'Scale': 'Escala',
        'Offset': 'Desplazamiento',
        'Light': 'Claro',
        'Light level': 'Nivel de luz',
      },
      'fi_FI': <String, String>{
        'Billboard': 'Katselusuunta',
        'Roll': 'Kallistuskulma',
        'Yaw': 'Kiertokulma',
        'Scale': 'Skaalaus',
        'Offset': 'Siirtymä',
        'Light': 'Vaalea',
        'Light level': 'Valaistustaso',
      },
      'fr_FR': <String, String>{
        'Billboard': 'Orientation',
        'Roll': 'Roulis',
        'Yaw': 'Lacet',
        'Scale': 'Échelle',
        'Offset': 'Décalage',
        'Light': 'Clair',
        'Light level': 'Niveau de lumière',
      },
      'he_IL': <String, String>{
        'Billboard': 'מצב פנייה',
        'Roll': 'גלגול',
        'Yaw': 'סבסוב',
        'Scale': 'קנה מידה',
        'Offset': 'היסט',
        'Light': 'בהיר',
        'Light level': 'רמת אור',
      },
      'it_IT': <String, String>{
        'Billboard': 'Orientamento',
        'Roll': 'Rollio',
        'Yaw': 'Imbardata',
        'Scale': 'Scala',
        'Offset': 'Scostamento',
        'Light': 'Chiaro',
        'Light level': 'Livello di luce',
      },
      'ja-JP': <String, String>{
        'Billboard': 'ビルボード',
        'Roll': 'ロール',
        'Yaw': 'ヨー',
        'Scale': 'スケール',
        'Offset': 'オフセット',
        'Light': 'ライト',
        'Light level': '光レベル',
      },
      'ko_KR': <String, String>{
        'Billboard': '빌보드',
        'Roll': '롤',
        'Yaw': '요',
        'Scale': '크기 조정',
        'Offset': '오프셋',
        'Light': '라이트',
        'Light level': '조명 수준',
      },
      'lt_LT': <String, String>{
        'Billboard': 'Orientacija',
        'Roll': 'Posvyrio kampas',
        'Yaw': 'Posūkis',
        'Scale': 'Mastelis',
        'Offset': 'Poslinkis',
        'Light': 'Šviesi',
        'Light level': 'Apšvietimo lygis',
      },
      'nl_NL': <String, String>{
        'Billboard': 'Oriëntatie',
        'Roll': 'Rolhoek',
        'Yaw': 'Gierhoek',
        'Scale': 'Schaal',
        'Offset': 'Verschuiving',
        'Light': 'Licht',
        'Light level': 'Lichtniveau',
      },
      'pl_PL': <String, String>{
        'Billboard': 'Tryb zwrócenia',
        'Roll': 'Przechylenie',
        'Yaw': 'Odchylenie',
        'Scale': 'Skala',
        'Offset': 'Przesunięcie',
        'Light': 'Jasny',
        'Light level': 'Poziom światła',
      },
      'pt_PT': <String, String>{
        'Billboard': 'Orientação',
        'Roll': 'Rolamento',
        'Yaw': 'Rotação horizontal',
        'Scale': 'Escala',
        'Offset': 'Deslocamento',
        'Light': 'Claro',
        'Light level': 'Nível de luz',
      },
      'ru_RU': <String, String>{
        'Billboard': 'Ориентация',
        'Roll': 'Крен',
        'Yaw': 'Рыскание',
        'Scale': 'Масштаб',
        'Offset': 'Смещение',
        'Light': 'Светлая',
        'Light level': 'Уровень освещения',
      },
      'tr_TR': <String, String>{
        'Billboard': 'Yönelim',
        'Roll': 'Yatış',
        'Yaw': 'Yatay dönüş',
        'Scale': 'Ölçek',
        'Offset': 'Ofset',
        'Light': 'Açık',
        'Light level': 'Işık seviyesi',
      },
      'vi_VI': <String, String>{
        'Billboard': 'Hướng mặt',
        'Roll': 'Góc nghiêng',
        'Yaw': 'Góc xoay ngang',
        'Scale': 'Tỷ lệ',
        'Offset': 'Độ lệch',
        'Light': 'Sáng',
        'Light level': 'Mức ánh sáng',
      },
      'zh_CN': <String, String>{
        'Billboard': '朝向模式',
        'Roll': '横滚',
        'Yaw': '偏航',
        'Scale': '缩放',
        'Offset': '偏移',
        'Light': '浅色',
        'Light level': '光照等级',
      },
      'zh_TW': <String, String>{
        'Billboard': '朝向模式',
        'Roll': '橫滾',
        'Yaw': '偏航',
        'Scale': '縮放',
        'Offset': '偏移',
        'Light': '淺色',
        'Light level': '光照等級',
      },
    };

const Map<String, Map<String, String>> _finalActionGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{
        'Home': 'Startseite',
        'Duplicate': 'Duplizieren',
        'Move': 'Verschieben',
        'Reset': 'Zurücksetzen',
        'Import': 'Importieren',
        'Action': 'Aktion',
        'Actions': 'Aktionen',
      },
      'es_ES': <String, String>{
        'Home': 'Inicio',
        'Duplicate': 'Duplicar',
        'Move': 'Mover',
        'Reset': 'Restablecer',
        'Import': 'Importar',
        'Action': 'Acción',
        'Actions': 'Acciones',
      },
      'fi_FI': <String, String>{
        'Home': 'Aloitus',
        'Duplicate': 'Monista',
        'Move': 'Siirrä',
        'Reset': 'Palauta',
        'Import': 'Tuo',
        'Action': 'Toiminto',
        'Actions': 'Toiminnot',
      },
      'fr_FR': <String, String>{
        'Home': 'Accueil',
        'Duplicate': 'Dupliquer',
        'Move': 'Déplacer',
        'Reset': 'Réinitialiser',
        'Import': 'Importer',
        'Action': 'Action',
        'Actions': 'Actions',
      },
      'he_IL': <String, String>{
        'Home': 'בית',
        'Duplicate': 'שכפל',
        'Move': 'העבר',
        'Reset': 'אפס',
        'Import': 'ייבוא',
        'Action': 'פעולה',
        'Actions': 'פעולות',
      },
      'it_IT': <String, String>{
        'Home': 'Pagina iniziale',
        'Duplicate': 'Duplica',
        'Move': 'Sposta',
        'Reset': 'Ripristina',
        'Import': 'Importa',
        'Action': 'Azione',
        'Actions': 'Azioni',
      },
      'ja-JP': <String, String>{
        'Home': 'ホーム',
        'Duplicate': '複製',
        'Move': '移動',
        'Reset': 'リセット',
        'Import': 'インポート',
        'Action': 'アクション',
        'Actions': 'アクション',
      },
      'ko_KR': <String, String>{
        'Home': '홈',
        'Duplicate': '복제',
        'Move': '이동',
        'Reset': '재설정',
        'Import': '가져오기',
        'Export': '내보내기',
        'Action': '액션',
        'Actions': '액션',
      },
      'lt_LT': <String, String>{
        'Home': 'Pradžia',
        'Duplicate': 'Dubliuoti',
        'Move': 'Perkelti',
        'Reset': 'Atkurti',
        'Import': 'Importuoti',
        'Action': 'Veiksmas',
        'Actions': 'Veiksmai',
      },
      'nl_NL': <String, String>{
        'Home': 'Start',
        'Duplicate': 'Dupliceren',
        'Move': 'Verplaatsen',
        'Reset': 'Herstellen',
        'Import': 'Importeren',
        'Action': 'Actie',
        'Actions': 'Acties',
      },
      'pl_PL': <String, String>{
        'Home': 'Strona główna',
        'Duplicate': 'Duplikuj',
        'Move': 'Przenieś',
        'Reset': 'Resetuj',
        'Import': 'Importuj',
        'Action': 'Akcja',
        'Actions': 'Akcje',
      },
      'pt_PT': <String, String>{
        'Home': 'Início',
        'Duplicate': 'Duplicar',
        'Move': 'Mover',
        'Reset': 'Repor',
        'Import': 'Importar',
        'Action': 'Ação',
        'Actions': 'Ações',
      },
      'ru_RU': <String, String>{
        'Home': 'Главная',
        'Duplicate': 'Дублировать',
        'Move': 'Переместить',
        'Reset': 'Сбросить',
        'Import': 'Импортировать',
        'Action': 'Действие',
        'Actions': 'Действия',
      },
      'tr_TR': <String, String>{
        'Home': 'Ana sayfa',
        'Duplicate': 'Çoğalt',
        'Move': 'Taşı',
        'Reset': 'Sıfırla',
        'Import': 'İçe aktar',
        'Action': 'Eylem',
        'Actions': 'Eylemler',
      },
      'vi_VI': <String, String>{
        'Home': 'Trang chủ',
        'Duplicate': 'Nhân bản',
        'Move': 'Di chuyển',
        'Reset': 'Đặt lại',
        'Import': 'Nhập',
        'Action': 'Hành động',
        'Actions': 'Hành động',
      },
      'zh_CN': <String, String>{
        'Home': '主页',
        'Duplicate': '复制',
        'Move': '移动',
        'Reset': '重置',
        'Import': '导入',
        'Action': '操作',
        'Actions': '操作',
      },
      'zh_TW': <String, String>{
        'Home': '首頁',
        'Duplicate': '複製',
        'Move': '移動',
        'Reset': '重置',
        'Import': '匯入',
        'Action': '動作',
        'Actions': '動作',
      },
    };

const Map<String, Map<String, String>> _semanticUiGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{
        'Application': 'Anwendung',
        'Assets': 'Ressourcen',
        'Clip': 'Clip',
        'Clips': 'Clips',
        'Close on death': 'Beim Tod schließen',
        'Close on teleport': 'Beim Teleportieren schließen',
        'Collision planes': 'Kollisionsflächen',
        'Count': 'Anzahl',
        'Cull height': 'Ausblendhöhe',
        'Cull width': 'Ausblendbreite',
        'Culling height': 'Ausblendhöhe',
        'Culling width': 'Ausblendbreite',
        'Editor': 'Editor',
        'Property map': 'Eigenschaftstabelle',
        'Well color': 'Farbmulde',
        'Well colour': 'Farbmulde',
        'World glob': 'Weltmuster',
        'World globs': 'Weltmuster',
        'Easing': 'Interpolationskurve',
        'Pan': 'Schwenken',
        'Snap': 'Rasterfang',
        'Light theme': 'Helles Thema',
        'Disabled worlds': 'Deaktivierte Welten',
        'Frame': 'Frame',
        'Frames': 'Frames',
      },
      'es_ES': <String, String>{
        'Application': 'Aplicación',
        'Assets': 'Recursos',
        'Clip': 'Clip',
        'Close on death': 'Cerrar al morir',
        'Close on teleport': 'Cerrar al teletransportarse',
        'Collision planes': 'Planos de colisión',
        'Count': 'Cantidad',
        'Cull height': 'Altura de recorte',
        'Cull width': 'Anchura de recorte',
        'Culling height': 'Altura de recorte',
        'Culling width': 'Anchura de recorte',
        'Well color': 'Color del hueco',
        'Well colour': 'Color del hueco',
        'World glob': 'Patrón de mundos',
        'World globs': 'Patrones de mundos',
        'Easing': 'Suavizado',
        'Pan': 'Desplazar',
        'Snap': 'Ajuste',
        'Light theme': 'Tema claro',
        'Disabled worlds': 'Mundos deshabilitados',
        'Fit preview': 'Ajustar vista previa',
        'Frame': 'Fotograma',
        'Frames': 'Fotogramas',
      },
      'fi_FI': <String, String>{
        'Assets': 'Resurssit',
        'Close on death': 'Sulje kuollessa',
        'Close on teleport': 'Sulje teleportattaessa',
        'Collision planes': 'Törmäystasot',
        'Count': 'Määrä',
        'Cull height': 'Rajauskorkeus',
        'Cull width': 'Rajausleveys',
        'Culling height': 'Rajauskorkeus',
        'Culling width': 'Rajausleveys',
        'Editor': 'Editori',
        'Property map': 'Ominaisuustaulukko',
        'Well color': 'Värisyvennyksen väri',
        'Well colour': 'Värisyvennyksen väri',
        'World glob': 'Maailman hakumalli',
        'World globs': 'Maailman hakumallit',
        'Easing': 'Liikkeen pehmennys',
        'Snap': 'Kohdistus',
        'Type': 'Tyyppi',
        'Light theme': 'Vaalea teema',
        'Disabled worlds': 'Käytöstä poistetut maailmat',
        'Frame': 'Ruutu',
        'Frames': 'Ruudut',
      },
      'fr_FR': <String, String>{
        'Application': 'Application',
        'Assets': 'Ressources',
        'Clip': 'Clip',
        'Clips': 'Clips',
        'Collision planes': 'Plans de collision',
        'Count': 'Nombre',
        'Cull height': 'Hauteur de masquage',
        'Cull width': 'Largeur de masquage',
        'Culling height': 'Hauteur de masquage',
        'Culling width': 'Largeur de masquage',
        'Property map': 'Table de propriétés',
        'Well color': 'Couleur du renfoncement',
        'Well colour': 'Couleur du renfoncement',
        'World glob': 'Motif de monde',
        'World globs': 'Motifs de monde',
        'Easing': 'Interpolation',
        'Pan': 'Déplacement',
        'Snap': 'Magnétisme',
        'Type': 'Type',
        'Light theme': 'Thème clair',
        'Disabled worlds': 'Mondes désactivés',
        'Fit preview': 'Ajuster l’aperçu',
        'Loading language': 'Chargement de la langue',
        'Frame': 'Image',
        'Frames': 'Images',
      },
      'it_IT': <String, String>{
        'Assets': 'Risorse',
        'Close on death': 'Chiudi alla morte',
        'Close on teleport': 'Chiudi al teletrasporto',
        'Collision planes': 'Piani di collisione',
        'Count': 'Quantità',
        'Cull height': 'Altezza di ritaglio',
        'Cull width': 'Larghezza di ritaglio',
        'Culling height': 'Altezza di ritaglio',
        'Culling width': 'Larghezza di ritaglio',
        'Editor': 'Editor',
        'Well color': 'Colore dell’incavo',
        'Well colour': 'Colore dell’incavo',
        'World glob': 'Pattern mondo',
        'World globs': 'Pattern mondi',
        'Easing': 'Interpolazione',
        'Pan': 'Panoramica',
        'Snap': 'Aggancio',
        'Type': 'Tipo',
        'Light theme': 'Tema chiaro',
        'Disabled worlds': 'Mondi disabilitati',
        'Duplicate': 'Duplica',
        'Export': 'Esporta',
        'Move': 'Sposta',
        'Frame': 'Fotogramma',
        'Frames': 'Fotogrammi',
      },
      'nl_NL': <String, String>{
        'Assets': 'Middelen',
        'Clip': 'Clip',
        'Clips': 'Clips',
        'Collision planes': 'Botsingsvlakken',
        'Count': 'Aantal',
        'Cull height': 'Uitsnijhoogte',
        'Cull width': 'Uitsnijbreedte',
        'Culling height': 'Uitsnijhoogte',
        'Culling width': 'Uitsnijbreedte',
        'Editor': 'Editor',
        'Property map': 'Eigenschappentabel',
        'Well color': 'Kleurvak',
        'Well colour': 'Kleurvak',
        'World glob': 'Wereldpatroon',
        'World globs': 'Wereldpatronen',
        'Easing': 'Versnellingscurve',
        'Pan': 'Verschuiven',
        'Snap': 'Uitlijnen',
        'Type': 'Type',
        'Duplicate': 'Dupliceren',
        'Fit preview': 'Voorbeeld passend maken',
        'Loading language': 'Taal wordt geladen',
        'Frame': 'Frame',
        'Frames': 'Frames',
      },
      'he_IL': <String, String>{
        'Clear': 'נקה',
        'Play': 'הפעל',
        'Condition': 'תנאי',
        'Block light': 'תאורת בלוק',
        'message player': 'שלח הודעה לשחקן',
        'run': 'הרץ',
        'Assets': 'משאבים',
        'Close on death': 'סגור בעת מוות',
        'Close on teleport': 'סגור בעת טלפורטציה',
        'Collision planes': 'מישורי התנגשות',
        'Count': 'כמות',
        'Cull height': 'גובה אזור ההסתרה',
        'Cull width': 'רוחב אזור ההסתרה',
        'Property map': 'מפת מאפיינים',
        'Well color': 'צבע השקע',
        'Well colour': 'צבע השקע',
        'World glob': 'תבנית עולם',
        'World globs': 'תבניות עולם',
        'Easing': 'עקומת תנועה',
        'Pan': 'הזזה',
        'Type': 'סוג',
        'Light theme': 'ערכת נושא בהירה',
        'Disabled worlds': 'עולמות מושבתים',
        'Frame': 'פריים',
        'Frames': 'פריימים',
      },
      'ja-JP': <String, String>{
        'Play': '再生',
        'Condition': '条件',
        'Block light': 'ブロックの明るさ',
        'message player': 'プレイヤーにメッセージを送信',
        'run': '実行',
        'order': '順序',
        'Assets': 'アセット',
        'Close on death': '死亡時に閉じる',
        'Cull height': 'カリング高さ',
        'Cull width': 'カリング幅',
        'Editor': 'エディター',
        'Property map': 'プロパティマップ',
        'Well color': 'くぼみの色',
        'Well colour': 'くぼみの色',
        'World glob': 'ワールドパターン',
        'World globs': 'ワールドパターン',
        'Disabled worlds': '無効化されたワールド',
      },
      'ko_KR': <String, String>{
        'Play': '재생',
        'Condition': '조건',
        'Block light': '블록 밝기',
        'message player': '플레이어에게 메시지 보내기',
        'run': '실행',
        'order': '순서',
        'Application': '애플리케이션',
        'Assets': '에셋',
        'Close on death': '사망 시 닫기',
        'Cull height': '컬링 높이',
        'Cull width': '컬링 너비',
        'Editor': '편집기',
        'Property map': '속성 맵',
        'Well color': '홈 색상',
        'Well colour': '홈 색상',
        'World glob': '월드 패턴',
        'World globs': '월드 패턴',
        'Easing': '이징',
        'Pan': '패닝',
        'Disabled worlds': '비활성화된 월드',
      },
      'lt_LT': <String, String>{
        'Clear': 'Išvalyti',
        'Play': 'Leisti',
        'Condition': 'Sąlyga',
        'Block light': 'Bloko šviesa',
        'message player': 'siųsti žinutę žaidėjui',
        'Application': 'Programa',
        'Assets': 'Ištekliai',
        'Close on death': 'Uždaryti mirus',
        'Close on teleport': 'Uždaryti teleportuojantis',
        'Collision planes': 'Susidūrimo plokštumos',
        'Count': 'Kiekis',
        'Cull height': 'Atvaizdavimo ribos aukštis',
        'Cull width': 'Atvaizdavimo ribos plotis',
        'Property map': 'Savybių lentelė',
        'Well color': 'Įdubos spalva',
        'Well colour': 'Įdubos spalva',
        'World glob': 'Pasaulio šablonas',
        'World globs': 'Pasaulių šablonai',
        'Easing': 'Judesio kreivė',
        'Pan': 'Slinkimas',
        'Snap': 'Pritraukimas',
        'Light theme': 'Šviesi tema',
        'Disabled worlds': 'Išjungti pasauliai',
        'Frame': 'Kadras',
        'Frames': 'Kadrai',
      },
      'pl_PL': <String, String>{
        'Clear': 'Wyczyść',
        'Play': 'Odtwórz',
        'Condition': 'Warunek',
        'Block light': 'Światło blokowe',
        'message player': 'wyślij wiadomość graczowi',
        'run': 'uruchom',
        'order': 'kolejność',
        'Application': 'Aplikacja',
        'Assets': 'Zasoby',
        'Close on death': 'Zamknij po śmierci',
        'Close on teleport': 'Zamknij przy teleportacji',
        'Collision planes': 'Płaszczyzny kolizji',
        'Count': 'Liczba',
        'Cull height': 'Wysokość obszaru renderowania',
        'Cull width': 'Szerokość obszaru renderowania',
        'Editor': 'Edytor',
        'Property map': 'Mapa właściwości',
        'Well color': 'Kolor zagłębienia',
        'Well colour': 'Kolor zagłębienia',
        'World glob': 'Wzorzec świata',
        'World globs': 'Wzorce światów',
        'Easing': 'Krzywa animacji',
        'Pan': 'Przesuwanie',
        'Snap': 'Przyciąganie',
        'Type': 'Typ',
        'Light theme': 'Jasny motyw',
        'Disabled worlds': 'Wyłączone światy',
        'Frame': 'Klatka',
        'Frames': 'Klatki',
      },
      'pt_PT': <String, String>{
        'Play': 'Reproduzir',
        'Condition': 'Condição',
        'Block light': 'Luz do bloco',
        'message player': 'enviar mensagem ao jogador',
        'run': 'executar',
        'order': 'ordem',
        'Application': 'Aplicação',
        'Assets': 'Recursos',
        'Clip': 'Clipe',
        'Clips': 'Clipes',
        'Close on death': 'Fechar ao morrer',
        'Close on teleport': 'Fechar ao teletransportar',
        'Collision planes': 'Planos de colisão',
        'Count': 'Quantidade',
        'Cull height': 'Altura de recorte',
        'Cull width': 'Largura de recorte',
        'Culling height': 'Altura de recorte',
        'Culling width': 'Largura de recorte',
        'Editor': 'Editor',
        'Property map': 'Mapa de propriedades',
        'Well color': 'Cor do seletor',
        'Well colour': 'Cor do seletor',
        'World glob': 'Padrão de mundos',
        'World globs': 'Padrões de mundos',
        'Easing': 'Suavização',
        'Pan': 'Deslocar',
        'Snap': 'Ajuste à grelha',
        'Type': 'Tipo',
        'Light theme': 'Tema claro',
        'Disabled worlds': 'Mundos desativados',
        'Duplicate': 'Duplicar',
        'Export': 'Exportar',
        'Move': 'Mover',
        'Fit preview': 'Ajustar pré-visualização',
        'Loading language': 'A carregar o idioma',
        'Frame': 'Fotograma',
        'Frames': 'Fotogramas',
        'Accent': 'Destaque',
        'Anchor': 'Ponto de ancoragem',
        'Anchors': 'Pontos de ancoragem',
        'Artboard': 'Área de trabalho',
        'Backdrop': 'Fundo',
        'Canvas': 'Área de desenho',
        'Card': 'Cartão',
        'Fixed': 'Fixo',
        'File': 'Ficheiro',
        'Files': 'Ficheiros',
        'Flat': 'Plano',
        'Entries': 'Entradas',
        'Home': 'Início',
        'External': 'Externo',
        'Drop stage': 'Palco de quedas',
        'Floating': 'Flutuante',
        'Cycle': 'Ciclo',
      },
      'ru_RU': <String, String>{
        'Play': 'Воспроизвести',
        'Condition': 'Условие',
        'Block light': 'Свет блока',
        'message player': 'отправить сообщение игроку',
        'run': 'выполнить',
        'order': 'порядок',
        'Application': 'Приложение',
        'Assets': 'Ресурсы',
        'Clip': 'Клип',
        'Clips': 'Клипы',
        'Close on death': 'Закрывать при смерти',
        'Close on teleport': 'Закрывать при телепортации',
        'Collision planes': 'Плоскости столкновений',
        'Count': 'Количество',
        'Cull height': 'Высота отсечения',
        'Cull width': 'Ширина отсечения',
        'Culling height': 'Высота отсечения',
        'Culling width': 'Ширина отсечения',
        'Editor': 'Редактор',
        'Property map': 'Карта свойств',
        'Well color': 'Цвет поля',
        'Well colour': 'Цвет поля',
        'World glob': 'Шаблон мира',
        'World globs': 'Шаблоны миров',
        'Easing': 'Кривая анимации',
        'Pan': 'Панорамирование',
        'Snap': 'Привязка',
        'Type': 'Тип',
        'Light theme': 'Светлая тема',
        'Disabled worlds': 'Отключённые миры',
        'Duplicate': 'Дублировать',
        'Export': 'Экспортировать',
        'Move': 'Переместить',
        'Fit preview': 'Вписать предпросмотр',
        'Loading language': 'Загрузка языка',
        'Frame': 'Кадр',
        'Frames': 'Кадры',
        'Accent': 'Акцентный цвет',
        'Anchor': 'Точка привязки',
        'Anchors': 'Точки привязки',
        'Artboard': 'Монтажная область',
        'Card': 'Карточка',
        'Fixed': 'Фиксированный',
        'Arrange': 'Расположить',
        'Flat': 'Плоский',
        'Entries': 'Записи',
        'Home': 'Главная',
        'External': 'Внешний',
        'Drop stage': 'Сцена выпадений',
        'Floating': 'Плавающий',
        'Cycle': 'Цикл',
      },
      'tr_TR': <String, String>{
        'Play': 'Oynat',
        'Condition': 'Koşul',
        'Block light': 'Blok ışığı',
        'message player': 'oyuncuya mesaj gönder',
        'run': 'çalıştır',
        'order': 'sıra',
        'Application': 'Uygulama',
        'Assets': 'Kaynaklar',
        'Clip': 'Klip',
        'Clips': 'Klipler',
        'Close on death': 'Ölünce kapat',
        'Close on teleport': 'Işınlanınca kapat',
        'Collision planes': 'Çarpışma düzlemleri',
        'Count': 'Sayı',
        'Cull height': 'Kırpma yüksekliği',
        'Cull width': 'Kırpma genişliği',
        'Culling height': 'Kırpma yüksekliği',
        'Culling width': 'Kırpma genişliği',
        'Editor': 'Editör',
        'Property map': 'Özellik haritası',
        'Well color': 'Renk alanı',
        'Well colour': 'Renk alanı',
        'World glob': 'Dünya deseni',
        'World globs': 'Dünya desenleri',
        'Easing': 'Yumuşatma',
        'Pan': 'Kaydırma',
        'Snap': 'Yakalama',
        'Type': 'Tür',
        'Light theme': 'Açık tema',
        'Disabled worlds': 'Devre dışı dünyalar',
        'Duplicate': 'Çoğalt',
        'Export': 'Dışa aktar',
        'Move': 'Taşı',
        'Fit preview': 'Önizlemeyi sığdır',
        'Loading language': 'Dil yükleniyor',
        'Frame': 'Kare',
        'Frames': 'Kareler',
        'Accent': 'Vurgu',
        'Anchor': 'Sabitleme noktası',
        'Anchors': 'Sabitleme noktaları',
        'Artboard': 'Çalışma yüzeyi',
        'Canvas': 'Tuval',
        'Card': 'Kart',
        'Fixed': 'Sabit',
        'Flat': 'Düz',
        'Entries': 'Kayıtlar',
        'Home': 'Ana sayfa',
        'External': 'Harici',
        'Drop stage': 'Düşme sahnesi',
        'Floating': 'Havada',
        'Cycle': 'Döngü',
      },
      'vi_VI': <String, String>{
        'Play': 'Phát',
        'Condition': 'Điều kiện',
        'Block light': 'Ánh sáng khối',
        'message player': 'gửi tin nhắn cho người chơi',
        'run': 'thực thi',
        'order': 'thứ tự',
        'Application': 'Ứng dụng',
        'Assets': 'Tài nguyên',
        'Clip': 'Đoạn hoạt ảnh',
        'Clips': 'Các đoạn hoạt ảnh',
        'Close on death': 'Đóng khi chết',
        'Close on teleport': 'Đóng khi dịch chuyển',
        'Collision planes': 'Các mặt phẳng va chạm',
        'Count': 'Số lượng',
        'Cull height': 'Chiều cao vùng hiển thị',
        'Cull width': 'Chiều rộng vùng hiển thị',
        'Culling height': 'Chiều cao vùng hiển thị',
        'Culling width': 'Chiều rộng vùng hiển thị',
        'Editor': 'Trình chỉnh sửa',
        'Property map': 'Bảng thuộc tính',
        'Well color': 'Màu ô chọn',
        'Well colour': 'Màu ô chọn',
        'World glob': 'Mẫu tên thế giới',
        'World globs': 'Các mẫu tên thế giới',
        'Easing': 'Đường cong chuyển động',
        'Pan': 'Di chuyển khung nhìn',
        'Snap': 'Bắt dính',
        'Type': 'Loại',
        'Light theme': 'Giao diện sáng',
        'Disabled worlds': 'Các thế giới bị vô hiệu hóa',
        'Duplicate': 'Nhân bản',
        'Export': 'Xuất',
        'Move': 'Di chuyển',
        'Fit preview': 'Vừa khung xem trước',
        'Loading language': 'Đang tải ngôn ngữ',
        'Frame': 'Khung hình',
        'Frames': 'Các khung hình',
        'Accent': 'Màu nhấn',
        'Anchor': 'Điểm neo',
        'Anchors': 'Các điểm neo',
        'Artboard': 'Bảng vẽ',
        'Canvas': 'Khung vẽ',
        'Card': 'Thẻ',
        'Cell': 'Ô',
        'Components': 'Thành phần',
        'Decoration': 'Trang trí',
        'Element': 'Phần tử',
        'Elements': 'Các phần tử',
        'Entries': 'Các mục',
        'Fixed': 'Cố định',
        'Flat': 'Phẳng',
        'Arrange': 'Sắp xếp',
        'Flow map': 'Sơ đồ luồng',
        'Flow maps': 'Các sơ đồ luồng',
        'Home': 'Trang chủ',
        'External': 'Bên ngoài',
        'Drop stage': 'Sân khấu vật phẩm rơi',
        'Floating': 'Lơ lửng',
        'Cycle': 'Chu kỳ',
      },
      'zh_CN': <String, String>{
        'Play': '播放',
        'Condition': '条件',
        'Block light': '方块光照',
        'message player': '向玩家发送消息',
        'run': '运行',
        'order': '顺序',
        'Application': '应用',
        'Assets': '资源',
        'Clip': '动画片段',
        'Clips': '动画片段',
        'Close on death': '死亡时关闭',
        'Close on teleport': '传送时关闭',
        'Collision planes': '碰撞平面',
        'Count': '数量',
        'Cull height': '剔除高度',
        'Cull width': '剔除宽度',
        'Culling height': '剔除高度',
        'Culling width': '剔除宽度',
        'Editor': '编辑器',
        'Property map': '属性映射',
        'Well color': '色槽颜色',
        'Well colour': '色槽颜色',
        'World glob': '世界匹配模式',
        'World globs': '世界匹配模式',
        'Easing': '缓动',
        'Pan': '平移',
        'Snap': '吸附',
        'Type': '类型',
        'Light theme': '浅色主题',
        'Disabled worlds': '已禁用的世界',
        'Duplicate': '复制',
        'Export': '导出',
        'Move': '移动',
        'Fit preview': '适应预览',
        'Loading language': '正在加载语言',
        'Frame': '帧',
        'Frames': '帧',
        'Accent': '强调色',
        'Anchor': '锚点',
        'Anchors': '锚点',
        'Canvas': '画布',
        'Card': '卡片',
        'Cell': '单元格',
        'Decoration': '装饰',
        'Entries': '条目',
        'Arrange': '排列',
        'Flat': '平面',
        'Audience': '受众',
        'Home': '主页',
        'External': '外部',
        'Action': '操作',
        'Actions': '操作',
        'Drop stage': '掉落物舞台',
        'Floating': '悬浮',
        'Cycle': '循环',
      },
      'zh_TW': <String, String>{
        'Play': '播放',
        'Condition': '條件',
        'Block light': '方塊光照',
        'message player': '傳送訊息給玩家',
        'run': '執行',
        'order': '順序',
        'Application': '應用程式',
        'Assets': '資源',
        'Clip': '動畫片段',
        'Clips': '動畫片段',
        'Close on death': '死亡時關閉',
        'Close on teleport': '傳送時關閉',
        'Collision planes': '碰撞平面',
        'Count': '數量',
        'Cull height': '剔除高度',
        'Cull width': '剔除寬度',
        'Culling height': '剔除高度',
        'Culling width': '剔除寬度',
        'Editor': '編輯器',
        'Property map': '屬性映射',
        'Well color': '色槽顏色',
        'Well colour': '色槽顏色',
        'World glob': '世界比對模式',
        'World globs': '世界比對模式',
        'Easing': '緩動',
        'Pan': '平移',
        'Snap': '吸附',
        'Type': '類型',
        'Light theme': '淺色主題',
        'Disabled worlds': '已停用的世界',
        'Duplicate': '複製',
        'Export': '匯出',
        'Move': '移動',
        'Fit preview': '調整預覽大小',
        'Loading language': '正在載入語言',
        'Frame': '影格',
        'Frames': '影格',
        'Accent': '強調色',
        'Anchor': '錨點',
        'Anchors': '錨點',
        'Canvas': '畫布',
        'Card': '卡片',
        'Cell': '儲存格',
        'Components': '元件',
        'Decoration': '裝飾',
        'Entries': '條目',
        'Arrange': '排列',
        'Flat': '平面',
        'Audience': '目標對象',
        'Home': '首頁',
        'External': '外部',
        'Action': '動作',
        'Actions': '動作',
        'Drop stage': '掉落物舞台',
        'Floating': '懸浮',
        'Cycle': '循環',
      },
    };

const Map<String, Map<String, String>>
_semanticQaGlossary = <String, Map<String, String>>{
  'de_DE': <String, String>{
    'Clear': 'Leeren',
    'Play': 'Abspielen',
    'play': 'abspielen',
    'Condition': 'Bedingung',
    'run': 'ausführen',
    'Run as': 'Ausführen als',
    'Run as player': 'Als Spieler ausführen',
    'order': 'Reihenfolge',
    'Match': 'Abgleich',
    'message player': 'Spieler benachrichtigen',
    'Real drops': 'Echte Drops',
    'Only player drops': 'Nur von Spielern fallen gelassene Gegenstände',
    'Only player-thrown drops': 'Nur von Spielern fallen gelassene Gegenstände',
    'Player drops only': 'Nur von Spielern fallen gelassene Gegenstände',
    'Item icons': 'Gegenstandssymbole',
    'Items from other plugins': 'Gegenstände aus anderen Plugins',
    'Move the item entity': 'Gegenstandsentität verschieben',
    'Drop stage': 'Drop-Bühne',
    'Material glob': 'Materialmuster',
    'Material globs': 'Materialmuster',
    'Track': 'Spur',
    'Scrub frames': 'Frames durchlaufen',
    'JSON completion': 'JSON-Codevervollständigung',
    'Gloss Editor': 'Gloss-Editor',
    'Plane normals': 'Ebenennormalen',
    'Ground roll': 'Rollen am Boden',
    'Runtime billboard facing': 'Laufzeit-Ausrichtung',
    'Icon facing': 'Symbolausrichtung',
    'Block light': 'Blocklicht',
    'View range': 'Sichtweite',
    'Native close': 'Natives Schließen',
    'Head by username': 'Kopf nach Benutzername',
    'Fuel ticks': 'Brennstoff-Ticks',
    'Fuel seconds': 'Brennstoffsekunden',
    'Fuel level': 'Brennstoffstand',
    'Live fuel': 'Aktueller Brennstoff',
    'Powered': 'Angetrieben',
    'Burn time': 'Brenndauer',
    'Cook time': 'Schmelzzeit',
    'Cook time total': 'Gesamte Schmelzzeit',
    'Brew time': 'Brauzeit',
    'Brew time total': 'Gesamte Brauzeit',
    'Airborne': 'In der Luft',
    'Floating': 'Schwebend',
    'Rolling': 'Rollend',
    'Rebounding': 'Abprallend',
    'Settle': 'Zur Ruhe kommen',
    'Settling': 'Beruhigt sich',
    'Settled': 'Zur Ruhe gekommen',
    'Wake': 'Aufwachen',
    'Hold': 'Halten',
    'Tab lists': 'Tablisten',
    'Tab screen': 'Tablisten-Bildschirm',
    'Tab list in game': 'Tablist im Spiel',
    'Tab list preview': 'Tablist-Vorschau',
    'Scoreboards': 'Scoreboards',
    'Scoreboard in game': 'Scoreboard im Spiel',
  },
  'es_ES': <String, String>{
    'Play': 'Reproducir',
    'play': 'reproducir',
    'run': 'ejecutar',
    'Run as player': 'Ejecutar como jugador',
    'Match': 'Coincidencia',
    'message player': 'Enviar mensaje al jugador',
    'Real drops': 'Drops reales',
    'Only player drops': 'Solo objetos soltados por jugadores',
    'Only player-thrown drops': 'Solo objetos soltados por jugadores',
    'Player drops only': 'Solo objetos soltados por jugadores',
    'Item icons': 'Iconos de objetos',
    'Items from other plugins': 'Objetos de otros plugins',
    'Move the item entity': 'Mover la entidad de objeto',
    'Drop stage': 'Escenario de drops',
    'Material glob': 'Patrón de materiales',
    'Material globs': 'Patrones de materiales',
    'Track': 'Pista',
    'Scrub frames': 'Recorrer fotogramas',
    'JSON completion': 'Autocompletado de JSON',
    'Log': 'Registro',
    'Cell': 'Celda',
    'Background': 'Fondo',
    'Inspector': 'Inspector',
    'Gloss Editor': 'Editor de Gloss',
    'Plane normals': 'Normales de los planos',
    'Ground roll': 'Rodadura por el suelo',
    'Runtime billboard facing': 'Orientación en tiempo de ejecución',
    'Block light': 'Luz de bloque',
    'View range': 'Distancia de visualización',
    'Native close': 'Cierre nativo',
    'Head by username': 'Cabeza por nombre de usuario',
    'Fuel ticks': 'Ticks de combustible',
    'Fuel seconds': 'Segundos de combustible',
    'Fuel level': 'Nivel de combustible',
    'Live fuel': 'Combustible actual',
    'Powered': 'Propulsada',
    'Burn time': 'Tiempo de combustión',
    'Cook time': 'Tiempo de fundición',
    'Cook time total': 'Tiempo total de fundición',
    'Brew time': 'Tiempo de preparación',
    'Brew time total': 'Tiempo total de preparación',
    'Airborne': 'En el aire',
    'Floating': 'Flotando',
    'Rolling': 'Rodando',
    'Rebounding': 'Rebotando',
    'Settle': 'Asentarse',
    'Settling': 'Estabilizándose',
    'Settled': 'Estabilizado',
    'Wake': 'Reactivarse',
    'Hold': 'Mantener',
    'Tab lists': 'Tablist',
    'Tab screen': 'Pantalla de la tablist',
    'Tab list in game': 'Tablist en el juego',
    'Tab list preview': 'Vista previa de la tablist',
  },
  'fi_FI': <String, String>{
    'Clear': 'Tyhjennä',
    'Play': 'Toista',
    'play': 'toista',
    'Condition': 'Ehto',
    'run': 'suorita',
    'Run as': 'Suorita käyttäjänä',
    'Run as player': 'Suorita pelaajana',
    'order': 'Järjestys',
    'Match': 'Vastaavuus',
    'message player': 'Lähetä viesti pelaajalle',
    'Real drops': 'Aidot pudotukset',
    'Only player drops': 'Vain pelaajien pudottamat esineet',
    'Only player-thrown drops': 'Vain pelaajien pudottamat esineet',
    'Player drops only': 'Vain pelaajien pudottamat esineet',
    'Item icons': 'Esinekuvakkeet',
    'Items from other plugins': 'Muiden lisäosien esineet',
    'Move the item entity': 'Siirrä esine-entiteettiä',
    'Drop stage': 'Pudotuslava',
    'Material glob': 'Materiaalin hakumalli',
    'Material globs': 'Materiaalien hakumallit',
    'Tracks': 'Raidat',
    'Scrub frames': 'Selaa ruutuja',
    'JSON completion': 'JSON-koodin täydennys',
    'Gloss Editor': 'Gloss-editori',
    'Plane normals': 'Tasojen normaalit',
    'Ground roll': 'Pyöriminen maassa',
    'Follow yaw': 'Seuraa kiertokulmaa',
    'Follow yaw and pitch': 'Seuraa kierto- ja kallistuskulmaa',
    'Runtime billboard facing': 'Ajonaikainen katselusuunta',
    'Icon facing': 'Kuvakkeen suuntaus',
    'Block grid': 'Lohkoruudukko',
    'Block light': 'Lohkovalo',
    'View range': 'Katseluetäisyys',
    'Native close': 'Natiivi sulkeminen',
    'Head by username': 'Pelaajan pää käyttäjänimen perusteella',
    'Fuel ticks': 'Polttoainetikit',
    'Fuel seconds': 'Polttoaineaika sekunteina',
    'Fuel level': 'Polttoainetaso',
    'Live fuel': 'Nykyinen polttoaine',
    'Powered': 'Käynnissä',
    'Burn time': 'Palamisaika',
    'Cook time': 'Sulatusaika',
    'Cook time total': 'Kokonaissulatusaika',
    'Brew time': 'Haudutusaika',
    'Brew time total': 'Kokonaishaudutusaika',
    'Airborne': 'Ilmassa',
    'Floating': 'Kelluva',
    'Rolling': 'Pyörivä',
    'Rebounding': 'Kimpoava',
    'Settle': 'Asettua',
    'Settling': 'Asettumassa',
    'Settled': 'Asettunut',
    'Wake': 'Herätä',
    'Hold': 'Pito',
    'Tab lists': 'Pelaajalistat',
    'Tab screen': 'Pelaajalistanäkymä',
    'Tab list in game': 'Pelaajalista pelissä',
    'Tab list preview': 'Pelaajalistan esikatselu',
  },
  'fr_FR': <String, String>{
    'Play': 'Lire',
    'play': 'lire',
    'Condition': 'Condition',
    'run': 'exécuter',
    'Run as player': 'Exécuter en tant que joueur',
    'order': 'ordre',
    'Match': 'Correspondance',
    'Actions': 'Actions',
    'message player': 'Envoyer un message au joueur',
    'Real drops': 'Drops réels',
    'Only player drops': 'Uniquement les objets lâchés par les joueurs',
    'Only player-thrown drops': 'Uniquement les objets lâchés par les joueurs',
    'Player drops only': 'Uniquement les objets lâchés par les joueurs',
    'Item icons': 'Icônes d’objets',
    'Items from other plugins': 'Objets d’autres plugins',
    'Move the item entity': 'Déplacer l’entité d’objet',
    'Drop stage': 'Scène des drops',
    'Material glob': 'Motif de matériaux',
    'Material globs': 'Motifs de matériaux',
    'Track': 'Piste',
    'Scrub frames': 'Parcourir les images',
    'JSON completion': 'Autocomplétion JSON',
    'Background': 'Arrière-plan',
    'Gloss Editor': 'Éditeur Gloss',
    'Plane normals': 'Normales des plans',
    'Ground roll': 'Roulement au sol',
    'Runtime billboard facing': 'Orientation à l’exécution',
    'Icon facing': 'Orientation de l’icône',
    'Block light': 'Lumière des blocs',
    'View range': 'Distance d’affichage',
    'Native close': 'Fermeture native',
    'Head by username': 'Tête par nom d’utilisateur',
    'Fuel ticks': 'Ticks de combustible',
    'Fuel seconds': 'Secondes de combustible',
    'Fuel level': 'Niveau de combustible',
    'Live fuel': 'Combustible actuel',
    'Powered': 'Motorisé',
    'Burn time': 'Durée de combustion',
    'Cook time': 'Temps de cuisson',
    'Cook time total': 'Temps de cuisson total',
    'Brew time': 'Temps d’alchimie',
    'Brew time total': 'Temps total d’alchimie',
    'Airborne': 'En l’air',
    'Floating': 'Flottant',
    'Rolling': 'En roulement',
    'Rebounding': 'En rebond',
    'Settle': 'Se stabiliser',
    'Settling': 'Stabilisation',
    'Settled': 'Stabilisé',
    'Wake': 'Réveil',
    'Hold': 'Maintien',
    'Tab lists': 'Tablists',
    'Tab screen': 'Écran de la tablist',
    'Tab list in game': 'Tablist en jeu',
    'Tab list preview': 'Aperçu de la tablist',
    'Scoreboards': 'Scoreboards',
    'Scoreboard in game': 'Scoreboard en jeu',
  },
  'he_IL': <String, String>{
    'Real drops': 'דרופים אמיתיים',
    'Only player drops': 'רק פריטים שהושלכו על ידי שחקנים',
    'Only player-thrown drops': 'רק פריטים שהושלכו על ידי שחקנים',
    'Player drops only': 'רק פריטים שהושלכו על ידי שחקנים',
    'Drop stage': 'במת הדרופים',
    'Material glob': 'תבנית חומרים',
    'Material globs': 'תבניות חומרים',
    'Scrub frames': 'דפדוף בפריימים',
    'JSON completion': 'השלמת קוד JSON',
    'Gloss Editor': 'עורך Gloss',
    'Plane normals': 'נורמלים למישורים',
    'Ground roll': 'גלגול על הקרקע',
    'Follow yaw': 'עקוב אחר הסבסוב',
    'Random yaw': 'סבסוב אקראי',
    'Random landing yaw': 'סבסוב אקראי בנחיתה',
    'Follow yaw and pitch': 'עקוב אחר סבסוב והטיה',
    'Runtime billboard facing': 'מצב פנייה בזמן ריצה',
    'Icon facing': 'כיוון הסמל',
    'Block grid': 'רשת בלוקים',
    'View range': 'טווח תצוגה',
    'Native close': 'סגירה מובנית',
    'Head by username': 'ראש לפי שם משתמש',
    'Keyframe': 'פריים מפתח',
    'Fuel ticks': 'טיקי דלק',
    'Fuel seconds': 'שניות דלק',
    'Fuel level': 'רמת דלק',
    'Live fuel': 'דלק נוכחי',
    'Powered': 'מונע',
    'Burn time': 'זמן בעירה',
    'Cook time': 'זמן התכה',
    'Cook time total': 'זמן התכה כולל',
    'Brew time': 'זמן רקיחה',
    'Brew time total': 'זמן רקיחה כולל',
    'Airborne': 'באוויר',
    'Floating': 'צף',
    'Rolling': 'מתגלגל',
    'Rebounding': 'קופץ חזרה',
    'Settle': 'להתייצב',
    'Settling': 'מתייצב',
    'Settled': 'התייצב',
    'Wake': 'התעוררות',
    'Hold': 'החזקה',
    'Tab lists': 'רשימות שחקנים',
    'Tab screen': 'מסך רשימת השחקנים',
    'Tab list in game': 'רשימת שחקנים במשחק',
    'Tab list preview': 'תצוגה מקדימה של רשימת השחקנים',
  },
  'it_IT': <String, String>{
    'Clear': 'Cancella',
    'Play': 'Riproduci',
    'play': 'riproduci',
    'run': 'esegui',
    'Run as': 'Esegui come',
    'Run as player': 'Esegui come giocatore',
    'Match': 'Corrispondenza',
    'message player': 'Invia un messaggio al giocatore',
    'Real drops': 'Drop reali',
    'Only player drops': 'Solo oggetti lasciati dai giocatori',
    'Only player-thrown drops': 'Solo oggetti lasciati dai giocatori',
    'Player drops only': 'Solo oggetti lasciati dai giocatori',
    'Item icons': 'Icone degli oggetti',
    'Items from other plugins': 'Oggetti da altri plugin',
    'Move the item entity': 'Sposta l’entità oggetto',
    'Drop stage': 'Scena dei drop',
    'Material glob': 'Pattern materiale',
    'Material globs': 'Pattern materiali',
    'Scrub frames': 'Scorri i fotogrammi',
    'JSON completion': 'Completamento automatico JSON',
    'Gloss Editor': 'Editor Gloss',
    'Plane normals': 'Normali dei piani',
    'Ground roll': 'Rotolamento a terra',
    'Runtime billboard facing': 'Orientamento a runtime',
    'Icon facing': 'Orientamento dell’icona',
    'Block grid': 'Griglia di blocchi',
    'Block light': 'Luce dei blocchi',
    'View range': 'Distanza di visualizzazione',
    'Native close': 'Chiusura nativa',
    'Head by username': 'Testa per nome utente',
    'Fuel ticks': 'Tick di combustibile',
    'Fuel seconds': 'Secondi di combustibile',
    'Fuel level': 'Livello del combustibile',
    'Live fuel': 'Combustibile attuale',
    'Powered': 'Alimentato',
    'Burn time': 'Tempo di combustione',
    'Cook time': 'Tempo di fusione',
    'Cook time total': 'Tempo totale di fusione',
    'Brew time': 'Tempo di distillazione',
    'Brew time total': 'Tempo totale di distillazione',
    'Airborne': 'In volo',
    'Floating': 'Galleggiante',
    'Rolling': 'Rotolamento',
    'Rebounding': 'Rimbalzante',
    'Settle': 'Assestarsi',
    'Settling': 'Assestamento',
    'Settled': 'Assestato',
    'Wake': 'Risveglio',
    'Hold': 'Mantieni',
    'Tab lists': 'Tablist',
    'Tab screen': 'Schermata della tablist',
    'Tab list in game': 'Tablist nel gioco',
    'Tab list preview': 'Anteprima della tablist',
  },
  'ja-JP': <String, String>{
    'Real drops': 'リアルドロップ',
    'Only player drops': 'プレイヤーが落としたアイテムのみ',
    'Only player-thrown drops': 'プレイヤーが落としたアイテムのみ',
    'Player drops only': 'プレイヤーが落としたアイテムのみ',
    'Move the item entity': 'アイテムエンティティを移動',
    'Drop stage': 'ドロップステージ',
    'Material glob': 'マテリアルパターン',
    'Material globs': 'マテリアルパターン',
    'Scrub frames': 'フレームをスクラブ',
    'JSON completion': 'JSON補完',
    'Library': 'ライブラリ',
    'Inspector': 'インスペクター',
    'Gloss Editor': 'Gloss エディター',
    'Plane normals': '平面法線',
    'Ground roll': '地面での転がり',
    'Runtime billboard facing': '実行時のビルボード方向',
    'Native close': 'ネイティブの閉じる動作',
    'Head by username': 'ユーザー名による頭',
    'Fuel ticks': '燃料ティック',
    'Fuel seconds': '燃料の残り秒数',
    'Fuel level': '燃料レベル',
    'Live fuel': '現在の燃料',
    'Powered': '動力あり',
    'Burn time': '燃焼時間',
    'Cook time': '精錬時間',
    'Cook time total': '合計精錬時間',
    'Brew time': '醸造時間',
    'Brew time total': '合計醸造時間',
    'Airborne': '空中',
    'Floating': '浮遊',
    'Rolling': '転がり中',
    'Rebounding': '跳ね返り中',
    'Settle': '静止へ移行',
    'Settling': '静止中',
    'Settled': '静止済み',
    'Wake': '再始動',
    'Hold': '保持',
    'Tab lists': 'タブリスト',
    'Tab screen': 'プレイヤーリスト画面',
    'Tab list in game': 'ゲーム内タブリスト',
    'Tab list preview': 'タブリストのプレビュー',
    'Scoreboard in game': 'ゲーム内のスコアボード',
  },
  'ko_KR': <String, String>{
    'Real drops': '실제 드롭',
    'Only player drops': '플레이어가 버린 아이템만',
    'Only player-thrown drops': '플레이어가 버린 아이템만',
    'Player drops only': '플레이어가 버린 아이템만',
    'Items from other plugins': '다른 플러그인의 아이템',
    'Move the item entity': '아이템 엔티티 이동',
    'Drop stage': '드롭 스테이지',
    'Material glob': '재료 패턴',
    'Material globs': '재료 패턴',
    'Scrub frames': '프레임 탐색',
    'JSON completion': 'JSON 자동 완성',
    'Library': '라이브러리',
    'Inspector': '인스펙터',
    'Gloss Editor': 'Gloss 편집기',
    'Gloss editor help': 'Gloss 편집기 도움말',
    'Plane normals': '평면 법선',
    'Ground roll': '지면 구르기',
    'Runtime billboard facing': '런타임 빌보드 방향',
    'Native close': '기본 닫기',
    'Head by username': '사용자 이름으로 플레이어 머리 찾기',
    'Fuel ticks': '연료 틱',
    'Fuel seconds': '연료 시간(초)',
    'Fuel level': '연료 수준',
    'Live fuel': '현재 연료',
    'Powered': '동력 공급됨',
    'Burn time': '연소 시간',
    'Cook time': '제련 시간',
    'Cook time total': '총 제련 시간',
    'Brew time': '양조 시간',
    'Brew time total': '총 양조 시간',
    'Airborne': '공중',
    'Floating': '떠 있음',
    'Rolling': '구르는 중',
    'Rebounding': '튕기는 중',
    'Settle': '정착 시작',
    'Settling': '정착 중',
    'Settled': '정착됨',
    'Wake': '깨어남',
    'Hold': '유지',
    'Tab lists': '플레이어 목록',
    'Tab screen': '플레이어 목록 화면',
    'Tab list in game': '게임 내 플레이어 목록',
    'Tab list preview': '플레이어 목록 미리보기',
  },
  'lt_LT': <String, String>{
    'Real drops': 'Tikri iškritę daiktai',
    'Only player drops': 'Tik žaidėjų išmesti daiktai',
    'Only player-thrown drops': 'Tik žaidėjų išmesti daiktai',
    'Player drops only': 'Tik žaidėjų išmesti daiktai',
    'Item icons': 'Daiktų piktogramos',
    'Items from other plugins': 'Kitų papildinių daiktai',
    'Move the item entity': 'Perkelti daikto esybę',
    'Drop stage': 'Iškritusių daiktų scena',
    'Material glob': 'Medžiagų šablonas',
    'Material globs': 'Medžiagų šablonai',
    'Track': 'Takelis',
    'Scrub frames': 'Peržiūrėti kadrus',
    'JSON completion': 'JSON automatinis užbaigimas',
    'Cell': 'Langelis',
    'Placeholder': 'Vietos žymuo',
    'Keyframe': 'Raktinis kadras',
    'Gloss Editor': 'Gloss redaktorius',
    'Player UUID': 'Žaidėjo UUID',
    'Pixelated player head': 'Pikseliuota žaidėjo galva',
    'Offset from the player': 'Poslinkis nuo žaidėjo',
    'Plane normals': 'Plokštumų normalės',
    'Ground roll': 'Riedėjimas žeme',
    'Follow yaw and pitch': 'Sekti posūkį ir posvyrį',
    'Runtime billboard facing': 'Vykdymo orientacija',
    'Icon facing': 'Piktogramos kryptis',
    'View range': 'Matomumo nuotolis',
    'Native close': 'Integruotas uždarymas',
    'Head by username': 'Galva pagal naudotojo vardą',
    'Fuel ticks': 'Kuro tiksai',
    'Fuel seconds': 'Kuro sekundės',
    'Fuel level': 'Kuro lygis',
    'Live fuel': 'Dabartinis kuras',
    'Powered': 'Varomas',
    'Burn time': 'Degimo laikas',
    'Cook time': 'Lydymo laikas',
    'Cook time total': 'Visas lydymo laikas',
    'Brew time': 'Eliksyrų virimo laikas',
    'Brew time total': 'Visas eliksyrų virimo laikas',
    'Airborne': 'Ore',
    'Floating': 'Plūduriuojantis',
    'Rolling': 'Riedėjimas',
    'Rebounding': 'Atšokimas',
    'Settle': 'Nusistovėti',
    'Settling': 'Nusistovėjimas',
    'Settled': 'Nusistovėjęs',
    'Wake': 'Pabudimas',
    'Hold': 'Išlaikyti',
    'Tab lists': 'Žaidėjų sąrašai',
    'Tab screen': 'Žaidėjų sąrašo ekranas',
    'Tab list in game': 'Žaidėjų sąrašas žaidime',
    'Tab list preview': 'Žaidėjų sąrašo peržiūra',
  },
  'nl_NL': <String, String>{
    'Clear': 'Wissen',
    'Play': 'Afspelen',
    'play': 'afspelen',
    'run': 'uitvoeren',
    'Run as player': 'Uitvoeren als speler',
    'order': 'Volgorde',
    'Match': 'Overeenkomst',
    'message player': 'Speler berichten',
    'Real drops': 'Echte drops',
    'Only player drops': 'Alleen door spelers gedropte voorwerpen',
    'Only player-thrown drops': 'Alleen door spelers gedropte voorwerpen',
    'Player drops only': 'Alleen door spelers gedropte voorwerpen',
    'Item icons': 'Voorwerppictogrammen',
    'Items from other plugins': 'Voorwerpen uit andere plug-ins',
    'Move the item entity': 'Voorwerpentiteit verplaatsen',
    'Drop stage': 'Drop-podium',
    'Material glob': 'Materiaalpatroon',
    'Material globs': 'Materiaalpatronen',
    'Track': 'Spoor',
    'Scrub frames': 'Door frames bladeren',
    'JSON completion': 'JSON-codeaanvulling',
    'Gloss Editor': 'Gloss-editor',
    'Gloss editor help': 'Help voor Gloss-editor',
    'Plane normals': 'Vlaknormalen',
    'Ground roll': 'Rollen over de grond',
    'Runtime billboard facing': 'Oriëntatie tijdens runtime',
    'Icon facing': 'Oriëntatie van pictogram',
    'Block grid': 'Blokkenraster',
    'Block light': 'Bloklicht',
    'View range': 'Weergaveafstand',
    'Native close': 'Ingebouwd sluiten',
    'Head by username': 'Hoofd op gebruikersnaam',
    'Fuel ticks': 'Brandstofticks',
    'Fuel seconds': 'Brandstofseconden',
    'Fuel level': 'Brandstofniveau',
    'Live fuel': 'Huidige brandstof',
    'Powered': 'Aangedreven',
    'Burn time': 'Brandduur',
    'Cook time': 'Smelttijd',
    'Cook time total': 'Totale smelttijd',
    'Brew time': 'Brouwduur',
    'Brew time total': 'Totale brouwduur',
    'Airborne': 'In de lucht',
    'Floating': 'Zwevend',
    'Rolling': 'Rollend',
    'Rebounding': 'Terugstuitend',
    'Settle': 'Tot rust komen',
    'Settling': 'Komt tot rust',
    'Settled': 'Tot rust gekomen',
    'Wake': 'Ontwaken',
    'Hold': 'Vasthouden',
    'Tab lists': 'Tablists',
    'Tab screen': 'Spelerslijstscherm',
    'Tab list in game': 'Tablist in het spel',
    'Tab list preview': 'Tablistvoorbeeld',
  },
  'pl_PL': <String, String>{
    'Real drops': 'Prawdziwe dropy',
    'Only player drops': 'Tylko przedmioty upuszczone przez graczy',
    'Only player-thrown drops': 'Tylko przedmioty upuszczone przez graczy',
    'Player drops only': 'Tylko przedmioty upuszczone przez graczy',
    'Item icons': 'Ikony przedmiotów',
    'Items from other plugins': 'Przedmioty z innych wtyczek',
    'Move the item entity': 'Przenieś encję przedmiotu',
    'Drop stage': 'Scena dropów',
    'Material glob': 'Wzorzec materiałów',
    'Material globs': 'Wzorce materiałów',
    'Track': 'Ścieżka',
    'Tracks': 'Ścieżki',
    'Scrub frames': 'Przewijaj klatki',
    'JSON completion': 'Autouzupełnianie JSON',
    'Log': 'Dziennik',
    'Elements': 'Elementy',
    'Gloss Editor': 'Edytor Gloss',
    'Offset from the player': 'Przesunięcie względem gracza',
    'Plane normals': 'Normalne płaszczyzn',
    'Ground roll': 'Toczenie po ziemi',
    'Follow yaw': 'Podążaj za odchyleniem',
    'Random yaw': 'Losowe odchylenie',
    'Runtime billboard facing': 'Tryb zwrócenia w czasie działania',
    'Icon facing': 'Orientacja ikony',
    'Block grid': 'Siatka bloków',
    'View range': 'Zasięg widoczności',
    'Native close': 'Natywne zamykanie',
    'Head by username': 'Głowa według nazwy użytkownika',
    'Fuel ticks': 'Tiki paliwa',
    'Fuel seconds': 'Sekundy paliwa',
    'Fuel level': 'Poziom paliwa',
    'Live fuel': 'Bieżące paliwo',
    'Powered': 'Napędzany',
    'Burn time': 'Czas spalania',
    'Cook time': 'Czas przetapiania',
    'Cook time total': 'Całkowity czas przetapiania',
    'Brew time': 'Czas warzenia',
    'Brew time total': 'Całkowity czas warzenia',
    'Airborne': 'W powietrzu',
    'Floating': 'Unoszenie się',
    'Rolling': 'Toczenie',
    'Rebounding': 'Odbijanie',
    'Settle': 'Ustabilizowanie',
    'Settling': 'Stabilizowanie',
    'Settled': 'Ustabilizowany',
    'Wake': 'Wybudzenie',
    'Hold': 'Utrzymaj',
    'Tab lists': 'Listy graczy',
    'Tab screen': 'Ekran listy graczy',
    'Tab list in game': 'Lista graczy w grze',
    'Tab list preview': 'Podgląd listy graczy',
  },
};

const Map<String, Map<String, String>> _alignmentDirectionGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{
        'Left': 'Links',
        'Right': 'Rechts',
        'left': 'links',
        'centred': 'horizontal zentriert',
        'right': 'rechts',
        'top': 'oben',
        'middle': 'vertikal zentriert',
        'bottom': 'unten',
      },
      'es_ES': <String, String>{
        'Left': 'Izquierda',
        'Right': 'Derecha',
        'left': 'a la izquierda',
        'centred': 'en el centro horizontal',
        'right': 'a la derecha',
        'top': 'arriba',
        'middle': 'en el centro vertical',
        'bottom': 'abajo',
      },
      'fi_FI': <String, String>{
        'Left': 'Vasen',
        'Right': 'Oikea',
        'left': 'vasempaan reunaan',
        'centred': 'vaakasuunnassa keskelle',
        'right': 'oikeaan reunaan',
        'top': 'yläreunaan',
        'middle': 'pystysuunnassa keskelle',
        'bottom': 'alareunaan',
      },
      'fr_FR': <String, String>{
        'Left': 'Gauche',
        'Right': 'Droite',
        'left': 'à gauche',
        'centred': 'horizontalement au centre',
        'right': 'à droite',
        'top': 'en haut',
        'middle': 'verticalement au centre',
        'bottom': 'en bas',
      },
      'he_IL': <String, String>{
        'Left': 'שמאל',
        'Right': 'ימין',
        'left': 'לשמאל',
        'centred': 'למרכז האופקי',
        'right': 'לימין',
        'top': 'למעלה',
        'middle': 'למרכז האנכי',
        'bottom': 'למטה',
      },
      'it_IT': <String, String>{
        'Left': 'Sinistra',
        'Right': 'Destra',
        'left': 'a sinistra',
        'centred': 'al centro in orizzontale',
        'right': 'a destra',
        'top': 'in alto',
        'middle': 'al centro in verticale',
        'bottom': 'in basso',
      },
      'ja-JP': <String, String>{
        'Left': '左',
        'Right': '右',
        'left': '左に',
        'centred': '水平方向の中央に',
        'right': '右に',
        'top': '上に',
        'middle': '垂直方向の中央に',
        'bottom': '下に',
      },
      'ko_KR': <String, String>{
        'Left': '왼쪽',
        'Right': '오른쪽',
        'left': '왼쪽으로',
        'centred': '가로 중앙으로',
        'right': '오른쪽으로',
        'top': '위쪽으로',
        'middle': '세로 중앙으로',
        'bottom': '아래쪽으로',
      },
      'lt_LT': <String, String>{
        'Left': 'Kairė',
        'Right': 'Dešinė',
        'left': 'kairėje',
        'centred': 'horizontaliai centre',
        'right': 'dešinėje',
        'top': 'viršuje',
        'middle': 'vertikaliai centre',
        'bottom': 'apačioje',
      },
      'nl_NL': <String, String>{
        'Left': 'Links',
        'Right': 'Rechts',
        'left': 'links',
        'centred': 'horizontaal gecentreerd',
        'right': 'rechts',
        'top': 'bovenaan',
        'middle': 'verticaal gecentreerd',
        'bottom': 'onderaan',
      },
      'pl_PL': <String, String>{
        'Left': 'Lewo',
        'Right': 'Prawo',
        'left': 'do lewej',
        'centred': 'do środka w poziomie',
        'right': 'do prawej',
        'top': 'do góry',
        'middle': 'do środka w pionie',
        'bottom': 'do dołu',
      },
      'pt_PT': <String, String>{
        'Left': 'Esquerda',
        'Right': 'Direita',
        'left': 'à esquerda',
        'centred': 'ao centro na horizontal',
        'right': 'à direita',
        'top': 'em cima',
        'middle': 'ao centro na vertical',
        'bottom': 'em baixo',
      },
      'ru_RU': <String, String>{
        'Left': 'Влево',
        'Right': 'Вправо',
        'left': 'по левому краю',
        'centred': 'по центру по горизонтали',
        'right': 'по правому краю',
        'top': 'по верхнему краю',
        'middle': 'по центру по вертикали',
        'bottom': 'по нижнему краю',
      },
      'tr_TR': <String, String>{
        'Left': 'Sol',
        'Right': 'Sağ',
        'left': 'sola',
        'centred': 'yatay olarak ortaya',
        'right': 'sağa',
        'top': 'üste',
        'middle': 'dikey olarak ortaya',
        'bottom': 'alta',
      },
      'vi_VI': <String, String>{
        'Left': 'Trái',
        'Right': 'Phải',
        'left': 'sang trái',
        'centred': 'giữa theo chiều ngang',
        'right': 'sang phải',
        'top': 'lên trên',
        'middle': 'giữa theo chiều dọc',
        'bottom': 'xuống dưới',
      },
      'zh_CN': <String, String>{
        'Left': '左',
        'Right': '右',
        'left': '向左',
        'centred': '水平居中',
        'right': '向右',
        'top': '向上',
        'middle': '垂直居中',
        'bottom': '向下',
      },
      'zh_TW': <String, String>{
        'Left': '左',
        'Right': '右',
        'left': '向左',
        'centred': '水平置中',
        'right': '向右',
        'top': '向上',
        'middle': '垂直置中',
        'bottom': '向下',
      },
    };

const Map<String, Map<String, String>> _alignedComponentsPluralGlossary =
    <String, Map<String, String>>{
      'de_DE': <String, String>{
        'one': '{count} Komponente {alignment} ausgerichtet.',
        'other': '{count} Komponenten {alignment} ausgerichtet.',
      },
      'es_ES': <String, String>{
        'one': 'Se alineó {count} componente {alignment}.',
        'many': 'Se alinearon {count} componentes {alignment}.',
        'other': 'Se alinearon {count} componentes {alignment}.',
      },
      'fi_FI': <String, String>{
        'one': 'Kohdistettiin {count} komponentti {alignment}.',
        'other': 'Kohdistettiin {count} komponenttia {alignment}.',
      },
      'fr_FR': <String, String>{
        'one': '{count} composant aligné {alignment}.',
        'many': '{count} composants alignés {alignment}.',
        'other': '{count} composants alignés {alignment}.',
      },
      'he_IL': <String, String>{
        'one': '{count} רכיב יושר {alignment}.',
        'two': '{count} רכיבים יושרו {alignment}.',
        'other': '{count} רכיבים יושרו {alignment}.',
      },
      'it_IT': <String, String>{
        'one': '{count} componente allineato {alignment}.',
        'many': '{count} componenti allineati {alignment}.',
        'other': '{count} componenti allineati {alignment}.',
      },
      'ja-JP': <String, String>{'other': '{count} 個のコンポーネントを{alignment}揃えました。'},
      'ko_KR': <String, String>{'other': '{count}개 구성 요소를 {alignment} 정렬했습니다.'},
      'lt_LT': <String, String>{
        'one': 'Sulygiuotas {count} komponentas {alignment}.',
        'few': 'Sulygiuoti {count} komponentai {alignment}.',
        'other': 'Sulygiuota {count} komponentų {alignment}.',
      },
      'nl_NL': <String, String>{
        'one': '{count} component {alignment} uitgelijnd.',
        'other': '{count} componenten {alignment} uitgelijnd.',
      },
      'pl_PL': <String, String>{
        'one': 'Wyrównano {count} komponent {alignment}.',
        'few': 'Wyrównano {count} komponenty {alignment}.',
        'many': 'Wyrównano {count} komponentów {alignment}.',
        'other': 'Wyrównano {count} komponentów {alignment}.',
      },
      'pt_PT': <String, String>{
        'one': '{count} componente alinhado {alignment}.',
        'many': '{count} componentes alinhados {alignment}.',
        'other': '{count} componentes alinhados {alignment}.',
      },
      'ru_RU': <String, String>{
        'one': 'Выровнен {count} компонент {alignment}.',
        'few': 'Выровнено {count} компонента {alignment}.',
        'many': 'Выровнено {count} компонентов {alignment}.',
        'other': 'Выровнено {count} компонентов {alignment}.',
      },
      'tr_TR': <String, String>{
        'one': '{count} bileşen {alignment} hizalandı.',
        'other': '{count} bileşen {alignment} hizalandı.',
      },
      'vi_VI': <String, String>{
        'one': 'Đã căn {count} thành phần {alignment}.',
        'other': 'Đã căn {count} thành phần {alignment}.',
      },
      'zh_CN': <String, String>{'other': '已将 {count} 个组件{alignment}对齐。'},
      'zh_TW': <String, String>{'other': '已將 {count} 個元件{alignment}對齊。'},
    };

const Map<String, Map<String, String>> _folderCountPluralGlossary =
    <String, Map<String, String>>{
      'es_ES': <String, String>{
        'one': '{count} carpeta',
        'many': '{count} carpetas',
        'other': '{count} carpetas',
      },
      'fr_FR': <String, String>{
        'one': '{count} dossier',
        'many': '{count} dossiers',
        'other': '{count} dossiers',
      },
      'he_IL': <String, String>{
        'one': '{count} תיקייה',
        'two': '{count} תיקיות',
        'other': '{count} תיקיות',
      },
      'lt_LT': <String, String>{'other': '{count} aplankų'},
      'pl_PL': <String, String>{
        'one': '{count} folder',
        'few': '{count} foldery',
        'many': '{count} folderów',
        'other': '{count} folderów',
      },
    };

const Map<String, List<String>> _missingImageArchiveTranslationBans =
    <String, List<String>>{
      'de_DE': <String>['reißverschluss'],
      'es_ES': <String>['cremallera'],
      'fi_FI': <String>['vetoketju'],
    };

const Map<String, Map<String, String>> _missingImageArchiveRequirements =
    <String, Map<String, String>>{
      'lt_LT': <String, String>{
        'one': 'ZIP archyve',
        'few': 'ZIP archyve',
        'other': 'ZIP archyve',
      },
      'pl_PL': <String, String>{
        'few': 'w archiwum ZIP',
        'many': 'w archiwum ZIP',
        'other': 'w archiwum ZIP',
      },
    };

const Map<String, String> _previewDerivedMessageGlossary = <String, String>{
  'Furnace': 'gloss.preview.theme.title.furnace',
  'Hopper': 'gloss.preview.theme.title.hopper',
  'Brewing stand': 'gloss.preview.theme.title.brewing_stand',
  'Beehive': 'gloss.preview.theme.title.beehive',
  'Cauldron': 'gloss.preview.theme.title.cauldron',
  'Chest': 'gloss.preview.theme.title.chest',
  'Dispenser': 'gloss.preview.theme.title.dispenser',
};

const Map<String, String> _lineGlossary = <String, String>{
  'de_DE': 'Zeile',
  'es_ES': 'Línea',
  'fi_FI': 'Rivi',
  'fr_FR': 'Ligne',
  'he_IL': 'שורה',
  'it_IT': 'Riga',
  'ja-JP': '行',
  'ko_KR': '줄',
  'lt_LT': 'Eilutė',
  'nl_NL': 'Regel',
  'pl_PL': 'Wiersz',
  'pt_PT': 'Linha',
  'ru_RU': 'Строка',
  'tr_TR': 'Satır',
  'vi_VI': 'Dòng',
  'zh_CN': '行',
  'zh_TW': '行',
};

const Map<String, String> _enderChestGlossary = <String, String>{
  'de_DE': 'Endertruhe',
  'es_ES': 'Cofre de ender',
  'fi_FI': 'Ender-arkku',
  'fr_FR': "Coffre de l'Ender",
  'he_IL': 'תיבת אנדר',
  'it_IT': 'Baule di ender',
  'ja-JP': 'エンダーチェスト',
  'ko_KR': '엔더 상자',
  'lt_LT': 'Enderio skrynia',
  'nl_NL': 'Enderkist',
  'pl_PL': 'Skrzynia Endu',
  'pt_PT': 'Baú do Ender',
  'ru_RU': 'Эндер-сундук',
  'tr_TR': 'Ender Sandığı',
  'vi_VI': 'Rương Ender',
  'zh_CN': '末影箱',
  'zh_TW': '終界箱',
};

const Map<String, String> _confirmGlossary = <String, String>{
  'de_DE': 'Bestätigen',
  'es_ES': 'Confirmar',
  'fi_FI': 'Vahvista',
};

const Map<String, Map<String, String>>
_openGlossary = <String, Map<String, String>>{
  'de_DE': <String, String>{'action.open': 'Öffnen', 'state.open': 'Offen'},
  'es_ES': <String, String>{'action.open': 'Abrir', 'state.open': 'Abierto'},
  'fi_FI': <String, String>{'action.open': 'Avaa', 'state.open': 'Avoinna'},
  'fr_FR': <String, String>{'action.open': 'Ouvrir', 'state.open': 'Ouvert'},
  'he_IL': <String, String>{'action.open': 'פתח', 'state.open': 'פתוח'},
  'it_IT': <String, String>{'action.open': 'Apri', 'state.open': 'Aperto'},
  'ja-JP': <String, String>{'action.open': '開く', 'state.open': '開いている'},
  'ko_KR': <String, String>{'action.open': '열기', 'state.open': '열림'},
  'lt_LT': <String, String>{
    'action.open': 'Atidaryti',
    'state.open': 'Atidaryta',
  },
  'nl_NL': <String, String>{'action.open': 'Openen', 'state.open': 'Open'},
  'pl_PL': <String, String>{'action.open': 'Otwórz', 'state.open': 'Otwarte'},
  'pt_PT': <String, String>{'action.open': 'Abrir', 'state.open': 'Aberto'},
  'ru_RU': <String, String>{'action.open': 'Открыть', 'state.open': 'Открыто'},
  'tr_TR': <String, String>{'action.open': 'Aç', 'state.open': 'Açık'},
  'vi_VI': <String, String>{'action.open': 'Mở', 'state.open': 'Đang mở'},
  'zh_CN': <String, String>{'action.open': '打开', 'state.open': '已打开'},
  'zh_TW': <String, String>{'action.open': '開啟', 'state.open': '已開啟'},
};

const Map<String, String> _trueGlossary = <String, String>{
  'de_DE': 'Wahr',
  'es_ES': 'Verdadero',
  'fi_FI': 'Tosi',
  'fr_FR': 'Vrai',
  'he_IL': 'אמת',
  'it_IT': 'Vero',
  'ja-JP': '真',
  'ko_KR': '참',
  'lt_LT': 'Tiesa',
  'nl_NL': 'Waar',
  'pl_PL': 'Prawda',
  'pt_PT': 'Verdadeiro',
  'ru_RU': 'Истина',
  'tr_TR': 'Doğru',
  'vi_VI': 'Đúng',
  'zh_CN': '真',
  'zh_TW': '真',
};

const Map<String, String> _falseGlossary = <String, String>{
  'de_DE': 'Falsch',
  'es_ES': 'Falso',
  'fi_FI': 'Epätosi',
  'fr_FR': 'Faux',
  'he_IL': 'שקר',
  'it_IT': 'Falso',
  'ja-JP': '偽',
  'ko_KR': '거짓',
  'lt_LT': 'Netiesa',
  'nl_NL': 'Onwaar',
  'pl_PL': 'Fałsz',
  'pt_PT': 'Falso',
  'ru_RU': 'Ложь',
  'tr_TR': 'Yanlış',
  'vi_VI': 'Sai',
  'zh_CN': '假',
  'zh_TW': '假',
};

const Map<String, String> _toggleNounGlossary = <String, String>{
  'de_DE': 'Umschalter',
  'es_ES': 'Conmutador',
  'fi_FI': 'Vaihtokytkin',
  'fr_FR': 'Interrupteur',
  'he_IL': 'מתג',
  'it_IT': 'Interruttore',
  'ja-JP': '切り替え',
  'ko_KR': '토글',
  'lt_LT': 'Perjungiklis',
  'nl_NL': 'Schakelaar',
  'pl_PL': 'Przełącznik',
  'pt_PT': 'Interruptor',
  'ru_RU': 'Переключатель',
  'tr_TR': 'Anahtar',
  'vi_VI': 'Nút chuyển',
  'zh_CN': '切换开关',
  'zh_TW': '切換開關',
};

final class LocalizationSource {
  const LocalizationSource({
    required this.messages,
    required this.contexts,
    required this.plurals,
    required this.previewMessages,
  });

  final Map<String, String> messages;
  final Map<String, String> contexts;
  final Map<String, Map<String, String>> plurals;
  final Map<String, String> previewMessages;
}

final class LocalizationCatalog {
  const LocalizationCatalog({
    required this.locale,
    required this.messages,
    required this.contexts,
    required this.plurals,
    required this.previewMessages,
  });

  factory LocalizationCatalog.fromJson(Map<String, Object?> json) {
    return LocalizationCatalog(
      locale: json['locale'] as String,
      messages: _stringMap(json['messages']),
      contexts: json['contexts'] == null
          ? <String, String>{}
          : _stringMap(json['contexts']),
      plurals: _pluralMap(json['plurals']),
      previewMessages: _stringMap(json['previewMessages']),
    );
  }

  final String locale;
  final Map<String, String> messages;
  final Map<String, String> contexts;
  final Map<String, Map<String, String>> plurals;
  final Map<String, String> previewMessages;

  Map<String, Object> toJson() => <String, Object>{
    'locale': locale,
    'messages': _sortedStringMap(messages),
    'contexts': _sortedStringMap(contexts),
    'plurals': <String, Map<String, String>>{
      for (final String key in plurals.keys.toList()..sort())
        key: _sortedStringMap(plurals[key]!),
    },
    'previewMessages': _sortedStringMap(previewMessages),
  };
}

LocalizationSource collectLocalizationSource(Directory root) {
  final Set<String> messages = <String>{};
  final Map<String, String> contexts = <String, String>{};
  final Map<String, Map<String, String>> plurals =
      <String, Map<String, String>>{};

  final Directory lib = Directory('${root.path}/lib');
  for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.contains(
      '${Platform.pathSeparator}l10n${Platform.pathSeparator}',
    )) {
      continue;
    }
    final String source = entity.readAsStringSync();
    _collectCalls(source, messages, contexts, plurals, entity.path);
    _collectNamedString(source, messages, <String>{'message', 'fix'});
    _collectFirstLiteralArgument(source, messages, 'HuiFormatException');
    _collectFirstLiteralArgument(
      source,
      messages,
      'PExprException',
      rejectInterpolated: true,
      path: entity.path,
    );
    _collectFirstLiteralArgument(
      source,
      messages,
      'JsonParseResult.failure',
      rejectInterpolated: true,
      path: entity.path,
    );
    _collectLiteralArgumentAt(
      source,
      messages,
      'PreviewVarProblem',
      1,
      entity.path,
      requireLiteral: true,
      skipFieldFormalConstructor: true,
    );
    if (entity.path.endsWith('${Platform.pathSeparator}validation.dart')) {
      _collectLiteralArgumentAt(source, messages, '_add', 2, entity.path);
    }
    if (entity.path.endsWith(
      '${Platform.pathSeparator}real_drop_script.dart',
    )) {
      _collectLiteralArgumentAt(source, messages, '_add', 2, entity.path);
      _collectStrictNamedString(source, messages, <String>{
        'message',
        'fix',
      }, entity.path);
    }
    _collectAssignedString(source, messages, <String>{
      '_lastError',
      '_lastFailure',
      '_indexedDbUnavailable',
    });
    _collectLiteralArguments(source, messages, 'WorkspaceRepositoryCorruption');
    if (entity.path.endsWith('${Platform.pathSeparator}workspace.dart')) {
      _collectNamedString(source, messages, <String>{
        'warning',
        'error',
        'fallbackError',
      });
    }
    if (entity.path.endsWith('${Platform.pathSeparator}workspace_panel.dart')) {
      _collectAssignedString(source, messages, <String>{'warning'});
      _collectLiteralArguments(source, messages, 'WorkspacePanelDecodeResult');
    }
    if (entity.path.endsWith('${Platform.pathSeparator}editor_store.dart')) {
      _collectStringCollectionInitializer(
        source,
        messages,
        '_directHistoryLabels',
      );
      for (final String helper in <String>[
        '_fail',
        '_inform',
        '_setCodeError',
      ]) {
        _collectFirstLiteralArgument(source, messages, helper);
      }
    }
    if (entity.path.endsWith('${Platform.pathSeparator}editor_sync.dart')) {
      _collectRequiredThrownMessage(
        source,
        messages,
        'EditorSyncFailure',
        entity.path,
      );
      _collectRequiredThrownMessage(
        source,
        messages,
        'EditorSyncConflict',
        entity.path,
      );
      _collectLiteralArguments(source, messages, 'super');
      _collectFirstLiteralArgument(source, messages, 'FormatException');
    }
    if (entity.path.endsWith('${Platform.pathSeparator}workspace.dart') ||
        entity.path.endsWith('${Platform.pathSeparator}workspace_route.dart')) {
      _collectFirstLiteralArgument(source, messages, 'FormatException');
    }
    if (entity.path.endsWith(
          '${Platform.pathSeparator}workspace_bundle.dart',
        ) ||
        entity.path.endsWith('${Platform.pathSeparator}workspace_route.dart')) {
      _collectNamedString(source, messages, <String>{'error'});
    }
    if (entity.path.endsWith(
      '${Platform.pathSeparator}workspace_bundle.dart',
    )) {
      _collectFirstLiteralArgument(
        source,
        messages,
        'WorkspaceBundleImportResult.failure',
      );
    }
  }

  for (final HuiFieldDoc doc in <HuiFieldDoc>[
    ...huiFieldDocs.values,
    ...huiGeneratedFieldDocs.values,
  ]) {
    _addMessage(messages, doc.title);
    _addMessage(messages, doc.body);
  }

  final Set<GlossJsonNode> visited = Set<GlossJsonNode>.identity();
  for (final GlossJsonObject schema in glossJsonSchemas.values) {
    _collectSchema(schema, messages, visited);
  }
  for (final GlossJsonType type in GlossJsonType.values) {
    _addMessage(messages, type.label);
  }

  for (final HuiTemplate template in huiTemplates) {
    _addMessage(messages, template.name);
    _addMessage(messages, template.description);
    for (final String highlight in template.highlights) {
      _addMessage(messages, highlight);
    }
  }
  for (final HuiPreviewTemplate template in huiPreviewTemplates) {
    _addMessage(messages, template.name);
    _addMessage(messages, template.description);
    for (final String highlight in template.highlights) {
      _addMessage(messages, highlight);
    }
  }
  for (final ShowcaseDrop drop in showcaseDrops) {
    _addMessage(messages, drop.displayName);
  }

  _collectFiniteDartMetadata(root, messages);
  _collectPreviewVariableDescriptions(root, messages);
  _addMessage(messages, huiDocumentTitleSource);
  _addMessage(messages, huiDocumentDescriptionSource);

  final Map<String, String> previewMessages = _readEnglishPreviewMessages(root);
  return LocalizationSource(
    messages: _sortedStringMap(<String, String>{
      for (final String message in messages) message: message,
    }),
    contexts: _sortedStringMap(contexts),
    plurals: <String, Map<String, String>>{
      for (final String key in plurals.keys.toList()..sort())
        key: _sortedStringMap(plurals[key]!),
    },
    previewMessages: _sortedStringMap(previewMessages),
  );
}

void _collectFirstLiteralArgument(
  String source,
  Set<String> messages,
  String callName, {
  bool rejectInterpolated = false,
  String? path,
}) {
  for (final _Call call in _callsNamed(source, callName)) {
    final _DartString? literal = _readAdjacentStrings(
      source,
      _skipTrivia(source, call.openParenthesis + 1),
    );
    if (literal == null) continue;
    if (literal.interpolated) {
      if (rejectInterpolated) {
        throw FormatException(
          '$callName must use a placeholder template, not interpolation, '
          'in $path.',
        );
      }
      continue;
    }
    _addMessage(messages, literal.value);
  }
}

void _collectLiteralArgumentAt(
  String source,
  Set<String> messages,
  String callName,
  int argumentIndex,
  String path, {
  bool requireLiteral = false,
  bool skipFieldFormalConstructor = false,
}) {
  for (final _Call call in _callsNamed(source, callName)) {
    int cursor = call.openParenthesis + 1;
    cursor = _skipTrivia(source, cursor);
    if (skipFieldFormalConstructor && source.startsWith('this.', cursor)) {
      continue;
    }
    bool foundArgument = false;
    for (int index = 0; index <= argumentIndex; index++) {
      cursor = _skipTrivia(source, cursor);
      if (cursor >= call.closeParenthesis) break;
      final int end = _firstArgumentEnd(source, cursor, call.closeParenthesis);
      if (index == argumentIndex) {
        foundArgument = true;
        final _DartString? literal = _readAdjacentStrings(source, cursor);
        if (literal != null) {
          if (literal.interpolated) {
            throw FormatException(
              '$callName argument ${argumentIndex + 1} must use a '
              'placeholder template, not interpolation, in $path.',
            );
          }
          _addMessage(messages, literal.value);
        } else if (requireLiteral) {
          throw FormatException(
            '$callName argument ${argumentIndex + 1} must be a literal '
            'placeholder template in $path.',
          );
        }
        break;
      }
      cursor = end + 1;
    }
    if (requireLiteral && !foundArgument) {
      throw FormatException(
        '$callName must provide literal argument ${argumentIndex + 1} in '
        '$path.',
      );
    }
  }
}

void _collectAssignedString(
  String source,
  Set<String> messages,
  Set<String> names,
) {
  final RegExp pattern = RegExp('\\b(${names.join('|')})\\s*(?:\\?\\?=|=)');
  for (final RegExpMatch match in pattern.allMatches(source)) {
    final _DartString? literal = _readAdjacentStrings(
      source,
      _skipTrivia(source, match.end),
    );
    if (literal != null) {
      if (!literal.interpolated) _addMessage(messages, literal.value);
      continue;
    }
    final int end = _statementEnd(source, match.end);
    if (end < 0) continue;
    final String expression = source.substring(match.end, end);
    if (!expression.contains('??') &&
        !RegExp(r'\?[^?]*:').hasMatch(expression)) {
      continue;
    }
    _collectLiteralStringsInRange(source, messages, match.end, end);
  }
}

void _collectStrictNamedString(
  String source,
  Set<String> messages,
  Set<String> names,
  String path,
) {
  final RegExp pattern = RegExp('\\b(${names.join('|')})\\s*:');
  for (final RegExpMatch match in pattern.allMatches(source)) {
    final _DartString? literal = _readAdjacentStrings(
      source,
      _skipTrivia(source, match.end),
    );
    if (literal == null) continue;
    if (literal.interpolated) {
      throw FormatException(
        '${match.group(1)} must use a placeholder template, not '
        'interpolation, in $path.',
      );
    }
    _addMessage(messages, literal.value);
  }
}

void _collectLiteralArguments(
  String source,
  Set<String> messages,
  String callName,
) {
  for (final _Call call in _callsNamed(source, callName)) {
    int cursor = call.openParenthesis + 1;
    while (cursor < call.closeParenthesis) {
      final _DartString? literal = _readString(source, cursor);
      if (literal != null) {
        if (!literal.interpolated) _addMessage(messages, literal.value);
        cursor = literal.end;
        continue;
      }
      if (source.startsWith('//', cursor)) {
        final int newline = source.indexOf('\n', cursor + 2);
        cursor = newline < 0 ? call.closeParenthesis : newline + 1;
        continue;
      }
      if (source.startsWith('/*', cursor)) {
        final int close = source.indexOf('*/', cursor + 2);
        cursor = close < 0 ? call.closeParenthesis : close + 2;
        continue;
      }
      cursor++;
    }
  }
}

void _collectRequiredThrownMessage(
  String source,
  Set<String> messages,
  String callName,
  String path,
) {
  for (final _Call call in _thrownCallsNamed(source, callName)) {
    final int start = _skipTrivia(source, call.openParenthesis + 1);
    final _DartString? literal = _readAdjacentStrings(source, start);
    if (literal != null) {
      if (literal.interpolated) {
        throw FormatException(
          '$callName must use a placeholder template, not interpolation, '
          'in $path.',
        );
      }
      _addMessage(messages, literal.value);
      continue;
    }
    final int end = _firstArgumentEnd(source, start, call.closeParenthesis);
    final String expression = source.substring(start, end).trim();
    if (expression.startsWith('_errorMessage(')) continue;
    if (expression.startsWith('workspace.lastError ??') ||
        expression.startsWith('images.lastError ??')) {
      _collectLiteralStringsInRange(source, messages, start, end);
      continue;
    }
    throw FormatException(
      '$callName must use literal English text in $path: $expression',
    );
  }
}

void _collectStringCollectionInitializer(
  String source,
  Set<String> messages,
  String name,
) {
  final RegExpMatch? declaration = RegExp('\\b$name\\s*=').firstMatch(source);
  if (declaration == null) return;
  final int brace = source.indexOf('{', declaration.end);
  final int bracket = source.indexOf('[', declaration.end);
  final int open = brace < 0
      ? bracket
      : bracket < 0
      ? brace
      : brace < bracket
      ? brace
      : bracket;
  if (open < 0) return;
  final String openCharacter = source[open];
  final String closeCharacter = openCharacter == '{' ? '}' : ']';
  final int close = _matchingDelimiter(
    source,
    open,
    openCharacter,
    closeCharacter,
  );
  if (close < 0) return;
  _collectLiteralStringsInRange(source, messages, open + 1, close);
}

void _collectLiteralStringsInRange(
  String source,
  Set<String> messages,
  int start,
  int end,
) {
  int cursor = start;
  while (cursor < end) {
    final _DartString? literal = _readString(source, cursor);
    if (literal != null) {
      if (!literal.interpolated) _addMessage(messages, literal.value);
      cursor = literal.end;
      continue;
    }
    cursor++;
  }
}

int _firstArgumentEnd(String source, int start, int callClose) {
  int parenthesisDepth = 0;
  int bracketDepth = 0;
  int braceDepth = 0;
  int cursor = start;
  while (cursor < callClose) {
    final _DartString? literal = _readString(source, cursor);
    if (literal != null) {
      cursor = literal.end;
      continue;
    }
    final String character = source[cursor];
    if (character == '(') parenthesisDepth++;
    if (character == ')') parenthesisDepth--;
    if (character == '[') bracketDepth++;
    if (character == ']') bracketDepth--;
    if (character == '{') braceDepth++;
    if (character == '}') braceDepth--;
    if (character == ',' &&
        parenthesisDepth == 0 &&
        bracketDepth == 0 &&
        braceDepth == 0) {
      return cursor;
    }
    cursor++;
  }
  return callClose;
}

int _statementEnd(String source, int start) {
  int parenthesisDepth = 0;
  int bracketDepth = 0;
  int braceDepth = 0;
  int cursor = start;
  while (cursor < source.length) {
    final _DartString? literal = _readString(source, cursor);
    if (literal != null) {
      cursor = literal.end;
      continue;
    }
    if (source.startsWith('//', cursor)) {
      final int newline = source.indexOf('\n', cursor + 2);
      cursor = newline < 0 ? source.length : newline + 1;
      continue;
    }
    if (source.startsWith('/*', cursor)) {
      final int close = source.indexOf('*/', cursor + 2);
      cursor = close < 0 ? source.length : close + 2;
      continue;
    }
    final String character = source[cursor];
    if (character == '(') parenthesisDepth++;
    if (character == ')') parenthesisDepth--;
    if (character == '[') bracketDepth++;
    if (character == ']') bracketDepth--;
    if (character == '{') braceDepth++;
    if (character == '}') braceDepth--;
    if (character == ';' &&
        parenthesisDepth == 0 &&
        bracketDepth == 0 &&
        braceDepth == 0) {
      return cursor;
    }
    cursor++;
  }
  return -1;
}

LocalizationCatalog readLocalizationCatalog(File file) {
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException('${file.path} must contain a JSON object.');
  }
  return LocalizationCatalog.fromJson(decoded);
}

String encodeLocalizationCatalog(LocalizationCatalog catalog) =>
    '${const JsonEncoder.withIndent('  ').convert(catalog.toJson())}\n';

LocalizationCatalog applyLockedLocalizationGlossary(
  LocalizationCatalog catalog,
  LocalizationSource source,
) {
  if (catalog.locale == 'en_US') return catalog;
  final Map<String, String> messages = <String, String>{...catalog.messages};
  final Map<String, String> contexts = <String, String>{...catalog.contexts};
  final Map<String, Map<String, String>> plurals =
      <String, Map<String, String>>{
        for (final MapEntry<String, Map<String, String>> entry
            in catalog.plurals.entries)
          entry.key: <String, String>{...entry.value},
      };

  void applyMessageMap(Map<String, String>? glossary) {
    if (glossary == null) return;
    for (final MapEntry<String, String> entry in glossary.entries) {
      if (source.messages.containsKey(entry.key)) {
        messages[entry.key] = entry.value;
      }
    }
  }

  void applyContextMap(Map<String, String>? glossary) {
    if (glossary == null) return;
    for (final MapEntry<String, String> entry in glossary.entries) {
      if (source.contexts.containsKey(entry.key)) {
        contexts[entry.key] = entry.value;
      }
    }
  }

  final Map<String, String> simpleMessages = <String, String>{};
  void addSimple(String key, Map<String, String> glossary) {
    final String? value = glossary[catalog.locale];
    if (value != null && source.messages.containsKey(key)) {
      simpleMessages[key] = value;
    }
  }

  addSimple('Confirm', _confirmGlossary);
  addSimple('True', _trueGlossary);
  addSimple('False', _falseGlossary);
  addSimple('Toggle', _toggleNounGlossary);
  addSimple('Scoreboard', _scoreboardGlossary);
  addSimple('scoreboard', _scoreboardLowerGlossary);
  addSimple('Tablist', _tablistGlossary);
  addSimple('tablist', _tablistLowerGlossary);
  addSimple('Custom item', _customItemGlossary);
  addSimple('Item', _itemGlossary);
  addSimple('Entry', _entryGlossary);
  addSimple('Entries', _entriesGlossary);
  addSimple('CLOSED', _closedGlossary);
  addSimple('Slot', _slotGlossary);
  addSimple('Player head', _playerHeadGlossary);
  addSimple('Ender chest', _enderChestGlossary);
  addSimple('Line', _lineGlossary);
  applyMessageMap(simpleMessages);
  for (final Map<String, String>? glossary in <Map<String, String>?>[
    _blockGlossary[catalog.locale],
    _tickGlossary[catalog.locale],
    _menuGlossary[catalog.locale],
    _panelGlossary[catalog.locale],
    _ambiguousLabelGlossary[catalog.locale],
    _finalActionGlossary[catalog.locale],
    _shortUiLabelGlossary[catalog.locale],
    _semanticUiGlossary[catalog.locale],
    _alignmentDirectionGlossary[catalog.locale],
    _previewSimMinecraftGlossary[catalog.locale],
    _semanticQaGlossary[catalog.locale],
  ]) {
    applyMessageMap(glossary);
  }
  applyMessageMap(semanticAuditGlossary[catalog.locale]);

  for (final Map<String, String>? glossary in <Map<String, String>?>[
    _pitchGlossary[catalog.locale],
    _openGlossary[catalog.locale],
    _soundCategoryGlossary[catalog.locale],
    _centerGlossary[catalog.locale],
    _animationBlendGlossary[catalog.locale],
    _historyBooleanGlossary[catalog.locale],
  ]) {
    applyContextMap(glossary);
  }
  final String? animationPlayer =
      _animationPlayerSurfaceGlossary[catalog.locale];
  if (animationPlayer != null &&
      source.contexts.containsKey('surface.animation_player')) {
    contexts['surface.animation_player'] = animationPlayer;
  }

  final Map<String, String>? aligned =
      _alignedComponentsPluralGlossary[catalog.locale];
  if (aligned != null && plurals.containsKey('toast.aligned_components')) {
    plurals['toast.aligned_components']!.addAll(aligned);
  }
  final Map<String, String>? folders =
      _folderCountPluralGlossary[catalog.locale];
  if (folders != null && plurals.containsKey('workspace.folder_count')) {
    plurals['workspace.folder_count']!.addAll(folders);
  }
  for (final MapEntry<String, String> entry
      in _previewDerivedMessageGlossary.entries) {
    if (!source.messages.containsKey(entry.key)) continue;
    final String? styled = catalog.previewMessages[entry.value];
    if (styled == null) continue;
    messages[entry.key] = styled.replaceAll(
      RegExp(r'&[0-9A-FK-ORa-fk-or]'),
      '',
    );
  }
  if (source.messages.containsKey("'Furnace'") &&
      messages.containsKey('Furnace')) {
    messages["'Furnace'"] = "'${messages['Furnace']}'";
  }
  const String formattedTextSample =
      '&fText, %papi%, |animation.id|, {{ expression }}';
  if (source.messages.containsKey(formattedTextSample) &&
      messages.containsKey('Text')) {
    messages[formattedTextSample] =
        '&f${messages['Text']}, %papi%, |animation.id|, {{ expression }}';
  }
  if (source.messages.containsKey('Original Gloss')) {
    messages['Original Gloss'] = 'Original Gloss';
  }
  if (catalog.locale == 'fr_FR' && source.messages.containsKey('Image')) {
    messages['Image'] = 'Image';
  }
  if (catalog.locale == 'pl_PL' && source.messages.containsKey('Folder')) {
    messages['Folder'] = 'Folder';
  }
  return LocalizationCatalog(
    locale: catalog.locale,
    messages: messages,
    contexts: contexts,
    plurals: plurals,
    previewMessages: catalog.previewMessages,
  );
}

Set<String> localizationPlaceholders(String value) => RegExp(
  r'\{([a-z][a-zA-Z0-9_]*)\}',
).allMatches(value).map((Match match) => match.group(1)!).toSet();

List<String> validateLocalizationCatalog(
  LocalizationCatalog catalog,
  LocalizationSource source,
) {
  final List<String> errors = <String>[];
  if (!localizationLocaleCodes.contains(catalog.locale)) {
    errors.add('Unsupported locale ${catalog.locale}.');
    return errors;
  }
  _validateKeys(
    'messages',
    catalog.messages.keys,
    source.messages.keys,
    errors,
  );
  _validateKeys(
    'contexts',
    catalog.contexts.keys,
    source.contexts.keys,
    errors,
  );
  _validateKeys('plurals', catalog.plurals.keys, source.plurals.keys, errors);
  _validateKeys(
    'previewMessages',
    catalog.previewMessages.keys,
    source.previewMessages.keys,
    errors,
  );

  for (final MapEntry<String, String> entry in source.messages.entries) {
    final String? translated = catalog.messages[entry.key];
    if (translated == null) continue;
    _validateTranslation(
      catalog.locale,
      'messages[${jsonEncode(entry.key)}]',
      entry.value,
      translated,
      errors,
    );
    if (catalog.locale == 'en_US' && translated != entry.value) {
      errors.add('English message ${jsonEncode(entry.key)} changed.');
    }
  }
  for (final MapEntry<String, String> entry in source.contexts.entries) {
    final String? translated = catalog.contexts[entry.key];
    if (translated == null) continue;
    _validateTranslation(
      catalog.locale,
      'contexts[${jsonEncode(entry.key)}]',
      entry.value,
      translated,
      errors,
    );
    if (catalog.locale == 'en_US' && translated != entry.value) {
      errors.add('English context ${jsonEncode(entry.key)} changed.');
    }
  }

  final List<String> requiredForms = localizationPluralForms[catalog.locale]!;
  for (final MapEntry<String, Map<String, String>> entry
      in source.plurals.entries) {
    final Map<String, String>? translatedForms = catalog.plurals[entry.key];
    if (translatedForms == null) continue;
    _validateKeys(
      'plurals[${jsonEncode(entry.key)}]',
      translatedForms.keys,
      requiredForms,
      errors,
    );
    for (final String form in requiredForms) {
      final String? translated = translatedForms[form];
      if (translated == null) continue;
      final String english = entry.value[form] ?? entry.value['other']!;
      _validateTranslation(
        catalog.locale,
        'plurals[${jsonEncode(entry.key)}].$form',
        english,
        translated,
        errors,
      );
      if (catalog.locale == 'en_US' && translated != english) {
        errors.add('English plural ${jsonEncode(entry.key)}.$form changed.');
      }
    }
  }

  for (final MapEntry<String, String> entry in source.previewMessages.entries) {
    final String? translated = catalog.previewMessages[entry.key];
    if (translated == null) continue;
    _validateTranslation(
      catalog.locale,
      'previewMessages[${jsonEncode(entry.key)}]',
      entry.value,
      translated,
      errors,
    );
    if (catalog.locale == 'en_US' && translated != entry.value) {
      errors.add('English preview message ${jsonEncode(entry.key)} changed.');
    }
  }
  _validateCatalogArtifacts(catalog, errors);
  _validateDomainGlossary(catalog, source, errors);
  return errors;
}

void _validateCatalogArtifacts(
  LocalizationCatalog catalog,
  List<String> errors,
) {
  final RegExp? forbiddenScript = _forbiddenScript(catalog.locale);
  for (final MapEntry<String, String> entry in _catalogStrings(catalog)) {
    final String value = entry.value;
    if (value.contains('\uFFFD')) {
      errors.add('${entry.key} contains U+FFFD.');
    }
    if (RegExp(
      r'(?:HUIKEEP|HUITOKEN|ZXQVTKN|XYZ\d{4}XYZ|QQQ\d{4}QQQ)',
      caseSensitive: false,
    ).hasMatch(value)) {
      errors.add('${entry.key} contains a translation marker.');
    }
    if (catalog.locale != 'en_US' &&
        RegExp(
          r'\b(?:in-game|human player|pointer hover|distance in blocks|game ticks?|game)\b',
          caseSensitive: false,
        ).hasMatch(value)) {
      errors.add('${entry.key} contains an untranslated domain marker.');
    }
    if (catalog.locale != 'en_US' &&
        RegExp(
          r'\b(in-game|game|human|player|item|skin|tick)(?:[\s-]+\1)\b',
          caseSensitive: false,
        ).hasMatch(value)) {
      errors.add('${entry.key} contains a doubled domain marker.');
    }
    final String repetitionText = value.replaceAll(
      RegExp(r'#[0-9A-Fa-f]{3,8}\b'),
      '',
    );
    if (RegExp(r'(.)\1{7,}', dotAll: true).hasMatch(repetitionText) ||
        RegExp(
          r'\b([\p{L}\p{N}]{2,})(?:[\s,;:|/·—–-]+\1){2,}\b',
          caseSensitive: false,
          unicode: true,
        ).hasMatch(value)) {
      errors.add('${entry.key} contains pathological repetition.');
    }
    if (forbiddenScript != null && forbiddenScript.hasMatch(value)) {
      errors.add('${entry.key} contains an unexpected writing system.');
    }
  }
}

void _validateDomainGlossary(
  LocalizationCatalog catalog,
  LocalizationSource source,
  List<String> errors,
) {
  if (catalog.locale == 'en_US') return;
  final List<String> skinTerms =
      _skinHeadTranslationBans[catalog.locale] ?? const <String>[];
  final List<String> itemTerms =
      _customItemTranslationBans[catalog.locale] ?? const <String>[];
  final List<String> playerTerms =
      _playerTranslationBans[catalog.locale] ?? const <String>[];
  final List<String> skinTermsGeneral =
      _skinTranslationBans[catalog.locale] ?? const <String>[];
  final List<String> tickTerms =
      _tickTranslationBans[catalog.locale] ?? const <String>[];
  final List<String> hoverTerms =
      _hoverTranslationBans[catalog.locale] ?? const <String>[];
  final List<String> blockDistanceTerms =
      _blockDistanceTranslationBans[catalog.locale] ?? const <String>[];
  final List<String> smeltTerms =
      _smeltTranslationBans[catalog.locale] ?? const <String>[];
  final List<String> brewTerms =
      _brewTranslationBans[catalog.locale] ?? const <String>[];
  final List<String> menuTerms =
      _menuTranslationBans[catalog.locale] ?? const <String>[];
  final List<String> panelTerms =
      _panelTranslationBans[catalog.locale] ?? const <String>[];
  final List<String> minecraftItemTerms =
      _minecraftItemTranslationBans[catalog.locale] ?? const <String>[];
  final List<String> pitchTerms =
      _pitchTranslationBans[catalog.locale] ?? const <String>[];
  for (final MapEntry<String, String> entry in catalog.messages.entries) {
    final String? english = source.messages[entry.key];
    if (english == null) continue;
    final String lowerEnglish = english.toLowerCase();
    final String lowerTranslation = entry.value.toLowerCase();
    if (lowerEnglish.contains('skin head') ||
        lowerEnglish.contains('player heads from skins')) {
      for (final String banned in skinTerms) {
        if (lowerTranslation.contains(banned)) {
          errors.add(
            'messages[${jsonEncode(entry.key)}] mistranslates Minecraft '
            'player heads from skins.',
          );
        }
      }
    }
    if (lowerEnglish.contains('custom item')) {
      for (final String banned in itemTerms) {
        if (lowerTranslation.contains(banned)) {
          errors.add(
            'messages[${jsonEncode(entry.key)}] mistranslates Minecraft '
            'custom items.',
          );
        }
      }
    }
    if (RegExp(r'\bplayer\b').hasMatch(lowerEnglish)) {
      _rejectDomainTerms(
        entry.key,
        lowerTranslation,
        playerTerms,
        'mistranslates a Minecraft player as a media player',
        errors,
      );
    }
    if (RegExp(r'\bskins?\b').hasMatch(lowerEnglish)) {
      _rejectDomainTerms(
        entry.key,
        lowerTranslation,
        skinTermsGeneral,
        'mistranslates Minecraft skin terminology',
        errors,
      );
    }
    if (RegExp(r'\bticks?\b').hasMatch(lowerEnglish)) {
      _rejectDomainTerms(
        entry.key,
        lowerTranslation,
        tickTerms,
        'mistranslates Minecraft game ticks',
        errors,
      );
    }
    if (RegExp(r'\bhover(?:ed|ing)?\b').hasMatch(lowerEnglish)) {
      _rejectDomainTerms(
        entry.key,
        lowerTranslation,
        hoverTerms,
        'mistranslates pointer or gaze hover state',
        errors,
      );
    }
    if (english.startsWith('Blocks ')) {
      _rejectDomainTerms(
        entry.key,
        lowerTranslation,
        blockDistanceTerms,
        'mistranslates blocks as a verb instead of a distance unit',
        errors,
      );
    }
    if (RegExp(r'\bsmelt(?:s|ed|ing)?\b').hasMatch(lowerEnglish)) {
      _rejectDomainTerms(
        entry.key,
        lowerTranslation,
        smeltTerms,
        'mistranslates furnace smelting',
        errors,
      );
    }
    if (RegExp(r'\bbrew(?:s|ed|ing)?\b').hasMatch(lowerEnglish)) {
      _rejectDomainTerms(
        entry.key,
        lowerTranslation,
        brewTerms,
        'mistranslates potion brewing as a beverage',
        errors,
      );
    }
    if (RegExp(r'\bmenus?\b').hasMatch(lowerEnglish)) {
      _rejectDomainTerms(
        entry.key,
        lowerTranslation,
        menuTerms,
        'mistranslates a UI menu as a restaurant menu',
        errors,
      );
    }
    if (RegExp(r'\bpanels?\b').hasMatch(lowerEnglish)) {
      _rejectDomainTerms(
        entry.key,
        lowerTranslation,
        panelTerms,
        'mistranslates an editor panel as a shield',
        errors,
      );
    }
    if (RegExp(r'\bitems?\b').hasMatch(lowerEnglish)) {
      final String location = 'messages[${jsonEncode(entry.key)}]';
      if (!(_minecraftItemDomainAllowlist[catalog.locale]?.contains(location) ??
          false)) {
        _rejectDomainTerms(
          entry.key,
          lowerTranslation,
          minecraftItemTerms,
          'mistranslates a Minecraft item as a generic entry or product',
          errors,
        );
      }
    }
    if (RegExp(r'\bpitch\b').hasMatch(lowerEnglish)) {
      _rejectDomainTerms(
        entry.key,
        lowerTranslation,
        pitchTerms,
        'mistranslates pitch as a field or playing area',
        errors,
      );
    }
  }
  for (final MapEntry<String, Map<String, String>> entry
      in catalog.plurals.entries) {
    final Map<String, String>? englishForms = source.plurals[entry.key];
    if (englishForms == null) continue;
    for (final MapEntry<String, String> form in entry.value.entries) {
      final String? english = englishForms[form.key] ?? englishForms['other'];
      if (english == null) continue;
      final String lowerEnglish = english.toLowerCase();
      final String lowerTranslation = form.value.toLowerCase();
      final String location = 'plurals[${jsonEncode(entry.key)}].${form.key}';
      if (lowerEnglish.contains('skin head') ||
          lowerEnglish.contains('player heads from skins')) {
        _rejectDomainTermsAt(
          location,
          lowerTranslation,
          skinTerms,
          'mistranslates Minecraft player heads from skins',
          errors,
        );
      }
      if (lowerEnglish.contains('custom item')) {
        _rejectDomainTermsAt(
          location,
          lowerTranslation,
          itemTerms,
          'mistranslates Minecraft custom items',
          errors,
        );
      }
      if (RegExp(r'\bplayer\b').hasMatch(lowerEnglish)) {
        _rejectDomainTermsAt(
          location,
          lowerTranslation,
          playerTerms,
          'mistranslates a Minecraft player as a media player',
          errors,
        );
      }
      if (RegExp(r'\bskins?\b').hasMatch(lowerEnglish)) {
        _rejectDomainTermsAt(
          location,
          lowerTranslation,
          skinTermsGeneral,
          'mistranslates Minecraft skin terminology',
          errors,
        );
      }
      if (RegExp(r'\bticks?\b').hasMatch(lowerEnglish)) {
        _rejectDomainTermsAt(
          location,
          lowerTranslation,
          tickTerms,
          'mistranslates Minecraft game ticks',
          errors,
        );
      }
      if (RegExp(r'\bpitch\b').hasMatch(lowerEnglish)) {
        _rejectDomainTermsAt(
          location,
          lowerTranslation,
          pitchTerms,
          'mistranslates pitch as a field or playing area',
          errors,
        );
      }
      if (RegExp(r'\bhover(?:ed|ing)?\b').hasMatch(lowerEnglish)) {
        _rejectDomainTermsAt(
          location,
          lowerTranslation,
          hoverTerms,
          'mistranslates pointer or gaze hover state',
          errors,
        );
      }
      if (RegExp(r'\bsmelt(?:s|ed|ing)?\b').hasMatch(lowerEnglish)) {
        _rejectDomainTermsAt(
          location,
          lowerTranslation,
          smeltTerms,
          'mistranslates furnace smelting',
          errors,
        );
      }
      if (RegExp(r'\bbrew(?:s|ed|ing)?\b').hasMatch(lowerEnglish)) {
        _rejectDomainTermsAt(
          location,
          lowerTranslation,
          brewTerms,
          'mistranslates potion brewing as a beverage',
          errors,
        );
      }
      if (RegExp(r'\bitems?\b').hasMatch(lowerEnglish)) {
        _rejectDomainTermsAt(
          location,
          lowerTranslation,
          minecraftItemTerms,
          'mistranslates a Minecraft item as a generic entry or product',
          errors,
        );
      }
    }
  }

  final Map<String, String>? expectedPitch = _pitchGlossary[catalog.locale];
  if (expectedPitch != null) {
    for (final MapEntry<String, String> entry in expectedPitch.entries) {
      if (source.contexts.containsKey(entry.key) &&
          catalog.contexts[entry.key] != entry.value) {
        errors.add(
          'contexts[${jsonEncode(entry.key)}] must be '
          '${jsonEncode(entry.value)}.',
        );
      }
    }
  }
  final Map<String, String>? expectedOpen = _openGlossary[catalog.locale];
  if (expectedOpen != null) {
    for (final MapEntry<String, String> entry in expectedOpen.entries) {
      if (source.contexts.containsKey(entry.key) &&
          catalog.contexts[entry.key] != entry.value) {
        errors.add(
          'contexts[${jsonEncode(entry.key)}] must be '
          '${jsonEncode(entry.value)}.',
        );
      }
    }
  }
  for (final Map<String, String>? glossary in <Map<String, String>?>[
    _soundCategoryGlossary[catalog.locale],
    _centerGlossary[catalog.locale],
    _animationBlendGlossary[catalog.locale],
    _historyBooleanGlossary[catalog.locale],
  ]) {
    if (glossary == null) continue;
    for (final MapEntry<String, String> entry in glossary.entries) {
      if (source.contexts.containsKey(entry.key) &&
          catalog.contexts[entry.key] != entry.value) {
        errors.add(
          'contexts[${jsonEncode(entry.key)}] must be '
          '${jsonEncode(entry.value)}.',
        );
      }
    }
  }
  final String? expectedAnimationPlayer =
      _animationPlayerSurfaceGlossary[catalog.locale];
  if (expectedAnimationPlayer != null &&
      source.contexts.containsKey('surface.animation_player') &&
      catalog.contexts['surface.animation_player'] != expectedAnimationPlayer) {
    errors.add(
      'contexts["surface.animation_player"] must be '
      '${jsonEncode(expectedAnimationPlayer)}.',
    );
  }
  final String? expectedConfirm = _confirmGlossary[catalog.locale];
  if (expectedConfirm != null &&
      source.messages.containsKey('Confirm') &&
      catalog.messages['Confirm'] != expectedConfirm) {
    errors.add('messages["Confirm"] must be ${jsonEncode(expectedConfirm)}.');
  }
  final String? expectedTrue = _trueGlossary[catalog.locale];
  if (expectedTrue != null &&
      source.messages.containsKey('True') &&
      catalog.messages['True'] != expectedTrue) {
    errors.add('messages["True"] must be ${jsonEncode(expectedTrue)}.');
  }
  final String? expectedFalse = _falseGlossary[catalog.locale];
  if (expectedFalse != null &&
      source.messages.containsKey('False') &&
      catalog.messages['False'] != expectedFalse) {
    errors.add('messages["False"] must be ${jsonEncode(expectedFalse)}.');
  }
  final String? expectedToggle = _toggleNounGlossary[catalog.locale];
  if (expectedToggle != null &&
      source.messages.containsKey('Toggle') &&
      catalog.messages['Toggle'] != expectedToggle) {
    errors.add('messages["Toggle"] must be ${jsonEncode(expectedToggle)}.');
  }
  final String? expectedScoreboard = _scoreboardGlossary[catalog.locale];
  if (expectedScoreboard != null &&
      source.messages.containsKey('Scoreboard') &&
      catalog.messages['Scoreboard'] != expectedScoreboard) {
    errors.add(
      'messages["Scoreboard"] must be ${jsonEncode(expectedScoreboard)}.',
    );
  }
  final String? expectedTablist = _tablistGlossary[catalog.locale];
  if (expectedTablist != null &&
      source.messages.containsKey('Tablist') &&
      catalog.messages['Tablist'] != expectedTablist) {
    errors.add('messages["Tablist"] must be ${jsonEncode(expectedTablist)}.');
  }
  final String? expectedScoreboardLower =
      _scoreboardLowerGlossary[catalog.locale];
  if (expectedScoreboardLower != null &&
      source.messages.containsKey('scoreboard') &&
      catalog.messages['scoreboard'] != expectedScoreboardLower) {
    errors.add(
      'messages["scoreboard"] must be '
      '${jsonEncode(expectedScoreboardLower)}.',
    );
  }
  final String? expectedTablistLower = _tablistLowerGlossary[catalog.locale];
  if (expectedTablistLower != null &&
      source.messages.containsKey('tablist') &&
      catalog.messages['tablist'] != expectedTablistLower) {
    errors.add(
      'messages["tablist"] must be ${jsonEncode(expectedTablistLower)}.',
    );
  }
  final String? expectedCustomItem = _customItemGlossary[catalog.locale];
  if (expectedCustomItem != null &&
      source.messages.containsKey('Custom item') &&
      catalog.messages['Custom item'] != expectedCustomItem) {
    errors.add(
      'messages["Custom item"] must be ${jsonEncode(expectedCustomItem)}.',
    );
  }
  final String? expectedItem = _itemGlossary[catalog.locale];
  if (expectedItem != null &&
      source.messages.containsKey('Item') &&
      catalog.messages['Item'] != expectedItem) {
    errors.add('messages["Item"] must be ${jsonEncode(expectedItem)}.');
  }
  final Map<String, String>? expectedBlocks = _blockGlossary[catalog.locale];
  if (expectedBlocks != null) {
    for (final MapEntry<String, String> entry in expectedBlocks.entries) {
      if (source.messages.containsKey(entry.key) &&
          catalog.messages[entry.key] != entry.value) {
        errors.add(
          'messages[${jsonEncode(entry.key)}] must be '
          '${jsonEncode(entry.value)}.',
        );
      }
    }
  }
  final Map<String, String>? expectedTicks = _tickGlossary[catalog.locale];
  if (expectedTicks != null) {
    for (final MapEntry<String, String> entry in expectedTicks.entries) {
      if (source.messages.containsKey(entry.key) &&
          catalog.messages[entry.key] != entry.value) {
        errors.add(
          'messages[${jsonEncode(entry.key)}] must be '
          '${jsonEncode(entry.value)}.',
        );
      }
    }
  }
  for (final MapEntry<String, Map<String, String>> glossary
      in const <MapEntry<String, Map<String, String>>>[
        MapEntry<String, Map<String, String>>('Entry', _entryGlossary),
        MapEntry<String, Map<String, String>>('Entries', _entriesGlossary),
        MapEntry<String, Map<String, String>>('CLOSED', _closedGlossary),
        MapEntry<String, Map<String, String>>('Slot', _slotGlossary),
        MapEntry<String, Map<String, String>>(
          'Player head',
          _playerHeadGlossary,
        ),
        MapEntry<String, Map<String, String>>(
          'Ender chest',
          _enderChestGlossary,
        ),
      ]) {
    final String? expected = glossary.value[catalog.locale];
    if (expected != null &&
        source.messages.containsKey(glossary.key) &&
        catalog.messages[glossary.key] != expected) {
      errors.add(
        'messages[${jsonEncode(glossary.key)}] must be '
        '${jsonEncode(expected)}.',
      );
    }
  }
  for (final Map<String, String>? glossary in <Map<String, String>?>[
    _menuGlossary[catalog.locale],
    _panelGlossary[catalog.locale],
    _ambiguousLabelGlossary[catalog.locale],
    _finalActionGlossary[catalog.locale],
    _shortUiLabelGlossary[catalog.locale],
    _semanticUiGlossary[catalog.locale],
    _alignmentDirectionGlossary[catalog.locale],
    _previewSimMinecraftGlossary[catalog.locale],
    _semanticQaGlossary[catalog.locale],
  ]) {
    if (glossary == null) continue;
    for (final MapEntry<String, String> entry in glossary.entries) {
      if (semanticAuditGlossary[catalog.locale]?.containsKey(entry.key) ??
          false) {
        continue;
      }
      if (source.messages.containsKey(entry.key) &&
          catalog.messages[entry.key] != entry.value) {
        errors.add(
          'messages[${jsonEncode(entry.key)}] must be '
          '${jsonEncode(entry.value)}.',
        );
      }
    }
  }
  final Map<String, String>? auditedMessages =
      semanticAuditGlossary[catalog.locale];
  if (auditedMessages != null) {
    for (final MapEntry<String, String> entry in auditedMessages.entries) {
      if (source.messages.containsKey(entry.key) &&
          catalog.messages[entry.key] != entry.value) {
        errors.add(
          'messages[${jsonEncode(entry.key)}] must be '
          '${jsonEncode(entry.value)} (semantic audit glossary).',
        );
      }
    }
  }
  final String? expectedLine = _lineGlossary[catalog.locale];
  if (expectedLine != null &&
      source.messages.containsKey('Line') &&
      catalog.messages['Line'] != expectedLine) {
    errors.add('messages["Line"] must be ${jsonEncode(expectedLine)}.');
  }
  final Map<String, String>? expectedAlignedComponents =
      _alignedComponentsPluralGlossary[catalog.locale];
  if (expectedAlignedComponents != null &&
      source.plurals.containsKey('toast.aligned_components')) {
    final Map<String, String>? actual =
        catalog.plurals['toast.aligned_components'];
    for (final MapEntry<String, String> entry
        in expectedAlignedComponents.entries) {
      if (actual?[entry.key] != entry.value) {
        errors.add(
          'plurals["toast.aligned_components"].${entry.key} must be '
          '${jsonEncode(entry.value)}.',
        );
      }
    }
  }
  final Map<String, String>? expectedFolderCount =
      _folderCountPluralGlossary[catalog.locale];
  if (expectedFolderCount != null &&
      source.plurals.containsKey('workspace.folder_count')) {
    final Map<String, String>? actual =
        catalog.plurals['workspace.folder_count'];
    for (final MapEntry<String, String> entry in expectedFolderCount.entries) {
      if (actual?[entry.key] != entry.value) {
        errors.add(
          'plurals["workspace.folder_count"].${entry.key} must be '
          '${jsonEncode(entry.value)}.',
        );
      }
    }
  }
  final List<String>? missingImageArchiveBans =
      _missingImageArchiveTranslationBans[catalog.locale];
  if (missingImageArchiveBans != null) {
    final Map<String, String>? forms =
        catalog.plurals['export.missing_image_count'];
    if (forms != null) {
      for (final MapEntry<String, String> form in forms.entries) {
        _rejectDomainTermsAt(
          'plurals["export.missing_image_count"].${form.key}',
          form.value.toLowerCase(),
          missingImageArchiveBans,
          'mistranslates a ZIP archive as a clothing zipper',
          errors,
        );
      }
    }
  }
  final Map<String, String>? missingImageArchiveRequirements =
      _missingImageArchiveRequirements[catalog.locale];
  if (missingImageArchiveRequirements != null) {
    final Map<String, String>? forms =
        catalog.plurals['export.missing_image_count'];
    if (forms != null) {
      for (final MapEntry<String, String> requirement
          in missingImageArchiveRequirements.entries) {
        if (!(forms[requirement.key] ?? '').contains(requirement.value)) {
          errors.add(
            'plurals["export.missing_image_count"].${requirement.key} must '
            'use ${jsonEncode(requirement.value)} for the ZIP archive.',
          );
        }
      }
    }
  }
  for (final MapEntry<String, String> entry
      in _previewDerivedMessageGlossary.entries) {
    if (!source.messages.containsKey(entry.key)) continue;
    final String? styledRuntimeValue = catalog.previewMessages[entry.value];
    if (styledRuntimeValue == null) continue;
    final String expected = styledRuntimeValue.replaceAll(
      RegExp(r'&[0-9A-FK-ORa-fk-or]'),
      '',
    );
    if (catalog.messages[entry.key] != expected) {
      errors.add(
        'messages[${jsonEncode(entry.key)}] must match the Gloss runtime '
        'term ${jsonEncode(expected)}.',
      );
    }
  }
  if (source.messages.containsKey("'Furnace'") &&
      catalog.messages.containsKey('Furnace')) {
    final String expected = "'${catalog.messages['Furnace']}'";
    if (catalog.messages["'Furnace'"] != expected) {
      errors.add(
        'messages["\'Furnace\'"] must use the localized runtime term '
        '${jsonEncode(expected)}.',
      );
    }
  }
  const String formattedTextSample =
      '&fText, %papi%, |animation.id|, {{ expression }}';
  if (source.messages.containsKey(formattedTextSample) &&
      catalog.messages.containsKey('Text')) {
    final String expected =
        '&f${catalog.messages['Text']}, %papi%, |animation.id|, '
        '{{ expression }}';
    if (catalog.messages[formattedTextSample] != expected) {
      errors.add(
        'messages[${jsonEncode(formattedTextSample)}] must localize Text '
        'while preserving its formatting examples.',
      );
    }
  }
  if (catalog.locale == 'fr_FR' &&
      source.messages.containsKey('Image') &&
      catalog.messages['Image'] != 'Image') {
    errors.add('messages["Image"] must be "Image".');
  }
  if (catalog.locale == 'pl_PL' &&
      source.messages.containsKey('Folder') &&
      catalog.messages['Folder'] != 'Folder') {
    errors.add('messages["Folder"] must be "Folder".');
  }
}

void _rejectDomainTerms(
  String key,
  String translation,
  List<String> banned,
  String description,
  List<String> errors,
) {
  _rejectDomainTermsAt(
    'messages[${jsonEncode(key)}]',
    translation,
    banned,
    description,
    errors,
  );
}

void _rejectDomainTermsAt(
  String location,
  String translation,
  List<String> banned,
  String description,
  List<String> errors,
) {
  for (final String term in banned) {
    if (!_containsDomainTerm(translation, term)) continue;
    errors.add('$location $description.');
    return;
  }
}

bool _containsDomainTerm(String translation, String term) {
  if (term == 'עור') {
    return RegExp(
      r'(?<![\p{L}])(?:ה|ל|ב)?עור(?![\p{L}])',
      unicode: true,
    ).hasMatch(translation);
  }
  if (term == 'soittim') {
    return RegExp(r'(?<![\p{L}])soittim', unicode: true).hasMatch(translation);
  }
  return translation.contains(term);
}

Iterable<MapEntry<String, String>> _catalogStrings(
  LocalizationCatalog catalog,
) sync* {
  for (final MapEntry<String, String> entry in catalog.messages.entries) {
    yield MapEntry<String, String>(
      'messages[${jsonEncode(entry.key)}]',
      entry.value,
    );
  }
  for (final MapEntry<String, String> entry in catalog.contexts.entries) {
    yield MapEntry<String, String>(
      'contexts[${jsonEncode(entry.key)}]',
      entry.value,
    );
  }
  for (final MapEntry<String, Map<String, String>> entry
      in catalog.plurals.entries) {
    for (final MapEntry<String, String> form in entry.value.entries) {
      yield MapEntry<String, String>(
        'plurals[${jsonEncode(entry.key)}].${form.key}',
        form.value,
      );
    }
  }
  for (final MapEntry<String, String> entry
      in catalog.previewMessages.entries) {
    yield MapEntry<String, String>(
      'previewMessages[${jsonEncode(entry.key)}]',
      entry.value,
    );
  }
}

RegExp? _forbiddenScript(String locale) => switch (locale) {
  'en_US' ||
  'de_DE' ||
  'es_ES' ||
  'fi_FI' ||
  'fr_FR' ||
  'it_IT' ||
  'lt_LT' ||
  'nl_NL' ||
  'pl_PL' ||
  'pt_PT' ||
  'tr_TR' ||
  'vi_VI' => RegExp(
    r'[\p{Script=Cyrillic}\p{Script=Hebrew}\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]',
    unicode: true,
  ),
  'he_IL' => RegExp(
    r'[\p{Script=Cyrillic}\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]',
    unicode: true,
  ),
  'ru_RU' => RegExp(
    r'[\p{Script=Hebrew}\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]',
    unicode: true,
  ),
  'ja-JP' => RegExp(
    r'[\p{Script=Cyrillic}\p{Script=Hebrew}\p{Script=Hangul}]',
    unicode: true,
  ),
  'ko_KR' => RegExp(
    r'[\p{Script=Cyrillic}\p{Script=Hebrew}\p{Script=Hiragana}\p{Script=Katakana}]',
    unicode: true,
  ),
  'zh_CN' || 'zh_TW' => RegExp(
    r'[\p{Script=Cyrillic}\p{Script=Hebrew}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]',
    unicode: true,
  ),
  _ => null,
};

void _validateTranslation(
  String locale,
  String location,
  String english,
  String translated,
  List<String> errors,
) {
  if (translated.trim().isEmpty) {
    errors.add('$location is empty.');
    return;
  }
  if (!_multisetsEqual(
    _placeholderCounts(english),
    _placeholderCounts(translated),
  )) {
    errors.add('$location has different placeholders.');
  }
  if (!_skipsProtectedTokenParity(location) &&
      !_isVisibleQuotedSample(english) &&
      !_multisetsEqual(
        _protectedTokenCounts(english),
        _protectedTokenCounts(translated),
      )) {
    errors.add('$location changed a protocol or code token.');
  }
  for (final MapEntry<String, int> entry in _contextualCodeTokenCounts(
    english,
  ).entries) {
    if (_literalTokenCount(translated, entry.key) < entry.value) {
      errors.add('$location changed a contextual code identifier.');
      break;
    }
  }
  if (!_multisetsEqual(
    _structuralDelimiterCounts(english),
    _structuralDelimiterCounts(translated),
  )) {
    errors.add('$location changed structural delimiters.');
  }
  if (_leadingWhitespace(english) != _leadingWhitespace(translated) ||
      _trailingWhitespace(english) != _trailingWhitespace(translated)) {
    errors.add('$location changed leading or trailing whitespace.');
  }
  _validateEnglishResidue(locale, location, english, translated, errors);
}

const Set<String> _localizedCodeLikeLocations = <String>{
  'messages["CLOSED"]',
  'contexts["history.boolean.true"]',
  'contexts["history.boolean.false"]',
  'contexts["sound_category.music"]',
  'messages["Preview false icon"]',
  'messages["Preview the false icon"]',
  'messages["Preview true icon"]',
  'messages["Preview the true icon"]',
};

bool _skipsProtectedTokenParity(String location) =>
    _localizedCodeLikeLocations.contains(location) ||
    location.startsWith('plurals["export.missing_image_count"].') ||
    location ==
        'messages["Velocity removed per tick in water. Clamped to 0..1."]';

void _validateKeys(
  String location,
  Iterable<String> actual,
  Iterable<String> expected,
  List<String> errors,
) {
  final Set<String> actualSet = actual.toSet();
  final Set<String> expectedSet = expected.toSet();
  final List<String> missing = expectedSet.difference(actualSet).toList()
    ..sort();
  final List<String> extra = actualSet.difference(expectedSet).toList()..sort();
  if (missing.isNotEmpty) {
    errors.add('$location is missing ${missing.join(', ')}.');
  }
  if (extra.isNotEmpty) {
    errors.add('$location has extra ${extra.join(', ')}.');
  }
}

Map<String, int> _placeholderCounts(String value) {
  final Map<String, int> counts = <String, int>{};
  for (final RegExpMatch match in RegExp(
    r'\{([a-z][a-zA-Z0-9_]*)\}',
  ).allMatches(value)) {
    final String name = match.group(1)!;
    counts[name] = (counts[name] ?? 0) + 1;
  }
  return counts;
}

final RegExp _protectedTokenPattern = RegExp(
  r'\{\{.*?\}\}|%[^%\s]+%|\|[^|\n]+\||`[^`\n]+`|https?://[A-Za-z0-9_./?=&%#:+~-]+|'
  r'(?:&[0-9A-FK-ORa-fk-or])+Gloss|'
  r'(?:/gloss|/hui)/[A-Za-z0-9][A-Za-z0-9_-]*|'
  r'(?:/gloss|/hui|/holoui)(?:\s+(?:item|menu|hologram))?(?:\s+(?:export|status|close|new|open|create|edit))?(?:\s+<[^>\n]+>)?(?:\s+\[[^\]\n]+\])?|'
  r'(?:plugins/Gloss|VolmitSoftware/docs|animations|shops|real-drops|menus|images)(?:/[A-Za-z0-9_{}<>-]+(?:\.[A-Za-z0-9_{}<>-]+)?)+/?|'
  r'(?:VolmitSoftware|volmit)\.com|'
  r'\b(?:Gloss|HoloUI|Paper|Bukkit|Folia|Mojang|TextDisplay|BungeeCord|Velocity|ViaVersion|EssentialsX|PlaceholderAPI|MiniMessage|IndexedDB|localStorage|Java|Dart|React|Iris|Volmit|VolmLib|GitHub|Discord|CraftEngine|ItemsAdder|Oraxen|Nexo|MMOItems|ExecutableItems|EcoItems|Slimefun|MythicMobs|HeadDatabase)\b|'
  r'''(?:"[A-Za-z0-9_.*:/+<>-]+"|'[A-Za-z0-9_.*:/+<>-]+')|'''
  r'\b[a-z][a-z0-9_.-]*:[a-z][a-z0-9_.*{}<>-]*\b|'
  r':[A-Za-z0-9_{}<>-]+:|U\+[A-Fa-f0-9X]+|\d+(?:\.\d+){1,}\+?|\d+(?:-by-|x)\d+|'
  r'[A-Za-z0-9_{}<>-]+\.(?:json|ya?ml|png|gif|zip|java|dart|md|txt|css|net)|'
  r'(?:gloss|ui|cell|label|vars|script|inventory|animation|minecraft|surge|player|papi|preview)(?:\.[A-Za-z0-9_*{}<>-]+)+|'
  r'(?:\bvip\b|\b(?:true|false|null|motd)\b|\b[A-Za-z0-9_]+\*)|'
  r'[A-Za-z][A-Za-z0-9]*_[A-Za-z0-9_]+|'
  r'[A-Z][A-Z0-9_]{2,}|'
  r'[a-z]+(?:[A-Z][A-Za-z0-9]*)+|'
  r'<[^>\n]+>|&[0-9A-FK-ORa-fk-or]|#[0-9A-Fa-f]{3,8}',
);

Map<String, int> _protectedTokenCounts(String value) {
  final Map<String, int> counts = <String, int>{};
  for (final RegExpMatch match in _protectedTokenPattern.allMatches(value)) {
    final String token = match.group(0)!;
    counts[token] = (counts[token] ?? 0) + 1;
  }
  return counts;
}

Map<String, int> _contextualCodeTokenCounts(String english) {
  final Map<String, int> counts = <String, int>{};
  void add(String token) {
    counts[token] = (counts[token] ?? 0) + 1;
  }

  for (final RegExpMatch match in RegExp(
    r'\b([A-Za-z][A-Za-z0-9_]*)(?=\()',
  ).allMatches(english)) {
    add(match.group(1)!);
  }
  for (final String heading in <String>['Accepted values:', 'Functions:']) {
    int cursor = 0;
    while (true) {
      final int start = english.indexOf(heading, cursor);
      if (start < 0) break;
      final int valueStart = start + heading.length;
      final int period = english.indexOf('.', valueStart);
      final int end = period < 0 ? english.length : period;
      for (final RegExpMatch match in RegExp(
        r'\b[A-Za-z][A-Za-z0-9_]*\b',
      ).allMatches(english.substring(valueStart, end))) {
        add(match.group(0)!);
      }
      cursor = end;
    }
  }
  if (english.contains('DROP_SCRIPT_FORMAT.md') &&
      english.contains('Variables include t, age, index, count, amount')) {
    for (final String token in <String>[
      't',
      'age',
      'index',
      'count',
      'amount',
      'onGround',
      'settled',
      'phase',
      'stateTime',
      'impactSpeed',
      'inWater',
      'inLava',
      'bounces',
      'velocityX',
      'velocityY',
      'velocityZ',
      'speed',
      'height',
      'blockLight',
      'skyLight',
      'random',
      'material',
      'isBlock',
      'isFlat',
      'isThin',
      'pi',
      'materialIs',
      'name',
      'materialMatches',
      'glob',
      'DROP_SCRIPT_FORMAT.md',
    ]) {
      counts.putIfAbsent(token, () => 1);
    }
  }
  return counts;
}

int _literalTokenCount(String value, String token) => RegExp(
  '(?<![A-Za-z0-9_])${RegExp.escape(token)}(?![A-Za-z0-9_])',
).allMatches(value).length;

const Map<String, Map<String, Set<String>>>
_unchangedNaturalLanguageAllowlistByReason = <String, Map<String, Set<String>>>{
  'brand and sibling-runtime contract literals': <String, Set<String>>{
    'de_DE': _runtimeContractInvariantLocations,
    'es_ES': _runtimeContractInvariantLocations,
    'fi_FI': _runtimeContractInvariantLocations,
    'fr_FR': _runtimeContractInvariantLocations,
    'he_IL': _runtimeContractInvariantLocations,
    'it_IT': _runtimeContractInvariantLocations,
    'ja-JP': _runtimeContractInvariantLocations,
    'ko_KR': _runtimeContractInvariantLocations,
    'lt_LT': _runtimeContractInvariantLocations,
    'nl_NL': _runtimeContractInvariantLocations,
    'pl_PL': _runtimeContractInvariantLocations,
    'pt_PT': _runtimeContractInvariantLocations,
    'ru_RU': _runtimeContractInvariantLocations,
    'tr_TR': _runtimeContractInvariantLocations,
    'vi_VI': _runtimeContractInvariantLocations,
    'zh_CN': _runtimeContractInvariantLocations,
    'zh_TW': _runtimeContractInvariantLocations,
  },
  'protocol-neutral units, dimensions, and axis labels': <String, Set<String>>{
    'de_DE': _invariantUnitLocations,
    'es_ES': _invariantUnitLocations,
    'fi_FI': _invariantUnitLocations,
    'fr_FR': _invariantUnitLocations,
    'he_IL': _invariantUnitLocations,
    'it_IT': _invariantUnitLocations,
    'ja-JP': _invariantUnitLocations,
    'ko_KR': _invariantUnitLocations,
    'lt_LT': _invariantUnitLocations,
    'nl_NL': _invariantUnitLocations,
    'pl_PL': _invariantUnitLocations,
    'pt_PT': _invariantUnitLocations,
    'ru_RU': _invariantUnitLocations,
    'tr_TR': _invariantUnitLocations,
    'vi_VI': _invariantUnitLocations,
    'zh_CN': _invariantUnitLocations,
    'zh_TW': _invariantUnitLocations,
  },
  'Gloss runtime feature terminology': <String, Set<String>>{
    'de_DE': <String>{'messages["Scoreboard"]', 'messages["Tablist"]'},
    'es_ES': <String>{'messages["Tablist"]', 'messages["tablist"]'},
    'fr_FR': <String>{
      'messages["Scoreboard"]',
      'messages["scoreboard"]',
      'messages["Tablist"]',
      'messages["tablist"]',
    },
    'it_IT': <String>{
      'messages["Scoreboard"]',
      'messages["scoreboard"]',
      'messages["Tablist"]',
      'messages["tablist"]',
    },
    'nl_NL': <String>{'messages["Tablist"]', 'messages["tablist"]'},
    'pt_PT': <String>{'messages["Tablist"]', 'messages["tablist"]'},
  },
  'official Minecraft client terminology': <String, Set<String>>{
    'de_DE': <String>{'messages["Block"]', 'messages["Tick"]'},
    'es_ES': <String>{'messages["Tick"]', 'messages["ticks"]'},
    'fr_FR': <String>{'messages["Tick"]', 'messages["ticks"]'},
    'it_IT': <String>{'messages["Tick"]'},
    'nl_NL': <String>{'messages["Tick"]', 'messages["ticks"]'},
    'pl_PL': <String>{'messages["Tick"]'},
    'pt_PT': <String>{'messages["Tick"]', 'messages["ticks"]'},
    'vi_VI': <String>{'messages["Tick"]'},
  },
  'established UI loanwords': <String, Set<String>>{
    'es_ES': <String>{'messages["Panel"]', 'messages["panel"]'},
    'fr_FR': <String>{
      'messages["Menu"]',
      'messages["menu"]',
      'messages["Image"]',
    },
    'it_IT': <String>{
      'messages["Menu"]',
      'messages["menu"]',
      'messages["Slot"]',
    },
    'nl_NL': <String>{'messages["Menu"]', 'messages["menu"]'},
    'pl_PL': <String>{
      'messages["Menu"]',
      'messages["menu"]',
      'messages["Panel"]',
      'messages["panel"]',
      'messages["Folder"]',
      'messages["Hologram"]',
      'messages["hologram"]',
      'messages["lobby"]',
      'plurals["workspace.folder_count"].one',
    },
    'pt_PT': <String>{
      'messages["Item"]',
      'messages["Menu"]',
      'messages["menu"]',
    },
    'tr_TR': <String>{'messages["Panel"]', 'messages["panel"]'},
  },
  'reviewed locale-specific cognates and technical loanwords':
      <String, Set<String>>{
        'de_DE': <String>{
          'messages["&fText, %papi%, |animation.id|, {{ expression }}"]',
          'messages["0 (transparent)"]',
          'messages["Animation"]',
          'messages["Clip"]',
          'messages["Clips"]',
          'messages["Code"]',
          'messages["Editor"]',
          'messages["Element"]',
          'messages["Element {value}"]',
          'messages["Emoji"]',
          'messages["Emoji {id}"]',
          'messages["Frame"]',
          'messages["Frames"]',
          'messages["Global"]',
          'messages["Hitbox"]',
          'messages["Horizontal"]',
          'messages["Index"]',
          'messages["Links"]',
          'messages["Material"]',
          'messages["Pause"]',
          'messages["Position"]',
          'messages["Push"]',
          'messages["Radius"]',
          'messages["Scoreboards"]',
          'messages["Server"]',
          'messages["Simulation"]',
          'messages["Slot"]',
          'messages["Text"]',
          'messages["Var"]',
          'messages["Vars"]',
        },
        'es_ES': <String>{
          'messages["Clip"]',
          'messages["Color"]',
          'messages["Inspector"]',
          'messages["Linear"]',
          'messages["Radius"]',
          'messages["Vars"]',
          'messages["vars"]',
          'messages["panel{repeat}"]',
        },
        'fi_FI': <String>{
          'messages["Emoji"]',
          'messages["Emoji {id}"]',
          'messages["emoji"]',
          'messages["sim"]',
        },
        'fr_FR': <String>{
          'messages["0 (transparent)"]',
          'messages["2 formats"]',
          'messages["3 formats"]',
          'messages["Action"]',
          'messages["Actions"]',
          'messages["Animations"]',
          'messages["Application"]',
          'messages["Clip"]',
          'messages["Clips"]',
          'messages["Code"]',
          'messages["Condition"]',
          'messages["Documentation"]',
          'messages["Documents"]',
          'messages["Hitbox"]',
          'messages["Images"]',
          'messages["Impact"]',
          'messages["Menu JSON"]',
          'messages["Menus"]',
          'messages["Rotation X"]',
          'messages["Rotation Y"]',
          'messages["Rotation Z"]',
          'messages["Scoreboards"]',
          'messages["Type"]',
          'messages["Var"]',
          'messages["Variables"]',
          'messages["Vars"]',
          'messages["accent"]',
          'messages["air"]',
          'messages["cube"]',
          'messages["distance"]',
          'messages["image {path}"]',
          'messages["inaudible"]',
          'previewMessages["gloss.preview.theme.title.dropper"]',
          'previewMessages["gloss.preview.theme.title.jukebox"]',
        },
        'it_IT': <String>{
          'messages["1 slot"]',
          'messages["Editor"]',
          'messages["Emoji {id}"]',
          'messages["Hitbox"]',
          'messages["schema {version}"]',
          'messages["Var"]',
          'messages["Vars"]',
          'messages["File"]',
        },
        'nl_NL': <String>{
          'messages["Clip"]',
          'messages["Clips"]',
          'messages["Code"]',
          'messages["Dispenser"]',
          'messages["Editor"]',
          'messages["Element {value}"]',
          'messages["Emoji"]',
          'messages["Emoji in chat"]',
          'messages["Emoji {id}"]',
          'messages["Filters"]',
          'messages["Frame"]',
          'messages["Frames"]',
          'messages["Hitbox"]',
          'messages["Overlays"]',
          'messages["Routes"]',
          'messages["Spawn"]',
          'messages["Type"]',
          'messages["Variant {id}"]',
          'messages["Variant {value}"]',
          'messages["Vars"]',
          'messages["accent"]',
          'messages["component-id"]',
          'messages["element"]',
          'messages["emoji"]',
          'messages["hologram"]',
          'messages["label"]',
          'messages["sim"]',
          'messages["variant {id}"]',
          'messages["variant: {id}"]',
          'messages["schema {version}"]',
          'messages["via proxy"]',
          'contexts["state.open"]',
          'plurals["export.component_count"].one',
          'plurals["workspace.document_count"].one',
          'previewMessages["gloss.preview.theme.title.container"]',
          'previewMessages["gloss.preview.theme.title.dispenser"]',
          'previewMessages["gloss.preview.theme.title.dropper"]',
        },
        'pt_PT': <String>{
          'messages["Editor"]',
          'messages["Emoji"]',
          'messages["Emoji {id}"]',
          'messages["Hitbox"]',
          'messages["Hitboxes"]',
          'messages["Linear"]',
          'messages["Menu JSON"]',
          'messages["Var"]',
          'messages["Vars"]',
          'messages["Volume"]',
          'messages["sim"]',
          'messages["vars"]',
          'messages["Menus"]',
          'plurals["duration.tick_count"].one',
          'plurals["duration.tick_count"].many',
          'plurals["duration.tick_count"].other',
          'plurals["real_drop.material_count"].one',
          'previewMessages["gloss.preview.theme.title.jukebox"]',
        },
        'tr_TR': <String>{
          'messages["Hitbox"]',
          'messages["Hologram"]',
          'messages["emoji"]',
        },
        'vi_VI': <String>{
          'plurals["duration.tick_count"].one',
          'plurals["duration.tick_count"].other',
        },
      },
};

const Set<String> _runtimeContractInvariantLocations = <String>{
  'messages["Original Gloss"]',
  'messages["drop.material == \'DIAMOND\'"]',
  'messages["variant-id"]',
  'messages["viewer.world == \'world\'"]',
  'messages["viewer.world == \'world\' && inGroup(\'viewer\', \'vip\')"]',
  'messages["vip, staff"]',
  'previewMessages["gloss.preview.stat.xp_gain"]',
  'previewMessages["gloss.preview.stat.xp_zero"]',
  'previewMessages["gloss.preview.state.surge_suffix"]',
};

const Set<String> _invariantUnitLocations = <String>{
  'messages[" x{count}"]',
  'messages["1 - smoothstep(0.7, 1, t)"]',
  'messages["250 ms"]',
  'messages["X"]',
  'messages["Y"]',
  'messages["Z"]',
  'messages["i"]',
  'messages["MOTDs"]',
  'messages["z"]',
  'messages["{dimensions} px · {size}"]',
  'messages["{id}.json"]',
  'messages["{path} ({width}x{height})"]',
  'messages["{value}x"]',
  'messages["{width}x{height}"]',
  'messages["{width}x{height} px ({characterWidth}, {lineHeight})"]',
  'messages["{amount}x {type}"]',
  'messages["{toStringAsFixed} / {toStringAsFixed2}s"]',
  'messages["*_SHELF glob"]',
  'messages["Packard Mill Cobble"]',
  'messages["Roadhouse 45"]',
  'messages["(text, textImage, animatedTextImage, item, block, customItem, entity, "]',
};

void _validateEnglishResidue(
  String locale,
  String location,
  String english,
  String translated,
  List<String> errors,
) {
  if (locale == 'en_US') return;
  final List<String> englishWords = _isVisibleQuotedSample(english)
      ? _unmaskedWords(english)
      : _naturalLanguageWords(english, contextualEnglish: english);
  if (englishWords.isEmpty) return;
  if (translated == english) {
    if (_allowsUnchangedNaturalLanguage(locale, location)) return;
    final int letterCount = englishWords.fold<int>(
      0,
      (int count, String word) => count + word.length,
    );
    if (englishWords.length >= 4 || letterCount >= 24) {
      errors.add('$location retains untranslated English prose.');
    } else {
      errors.add(
        '$location retains an English term without an allowlist entry.',
      );
    }
    return;
  }
  final List<String> translatedWords = _isVisibleQuotedSample(english)
      ? _unmaskedWords(translated)
      : _naturalLanguageWords(translated, contextualEnglish: english);
  if (_hasLongSharedNaturalLanguageRun(englishWords, translatedWords)) {
    if (location.startsWith(
          'messages["A string in the preview expression DSL,',
        ) ||
        location ==
            'messages["types (command, sound, message, teleport, connect, navigate). "]') {
      return;
    }
    errors.add('$location retains a long untranslated English fragment.');
  }
}

List<String> _naturalLanguageWords(
  String value, {
  required String contextualEnglish,
}) {
  String withoutPlaceholders = value.replaceAll(
    RegExp(r'\{[a-z][a-zA-Z0-9_]*\}'),
    ' ',
  );
  for (final String token in _contextualCodeTokenCounts(
    contextualEnglish,
  ).keys) {
    withoutPlaceholders = withoutPlaceholders.replaceAll(
      RegExp('(?<![A-Za-z0-9_])${RegExp.escape(token)}(?![A-Za-z0-9_])'),
      ' ',
    );
  }
  final String residue = withoutPlaceholders.replaceAll(
    _protectedTokenPattern,
    ' ',
  );
  return _unmaskedWords(residue);
}

List<String> _unmaskedWords(String value) {
  return RegExp(
    r"\p{L}+(?:['’]\p{L}+)?",
    unicode: true,
  ).allMatches(value).map((RegExpMatch match) => match.group(0)!).toList();
}

bool _isVisibleQuotedSample(String english) =>
    english == "'Furnace'" || english == "'Label text'";

bool _hasLongSharedNaturalLanguageRun(
  List<String> english,
  List<String> translated,
) {
  final List<String> lowerEnglish = english
      .map((String word) => word.toLowerCase())
      .toList();
  final List<String> lowerTranslated = translated
      .map((String word) => word.toLowerCase())
      .toList();
  for (int sourceStart = 0; sourceStart < lowerEnglish.length; sourceStart++) {
    for (
      int targetStart = 0;
      targetStart < lowerTranslated.length;
      targetStart++
    ) {
      int words = 0;
      int letters = 0;
      while (sourceStart + words < lowerEnglish.length &&
          targetStart + words < lowerTranslated.length &&
          lowerEnglish[sourceStart + words] ==
              lowerTranslated[targetStart + words]) {
        letters += lowerEnglish[sourceStart + words].length;
        words++;
        if (words >= 5 || letters >= 32) return true;
      }
    }
  }
  return false;
}

bool _allowsUnchangedNaturalLanguage(String locale, String location) {
  for (final Map<String, Set<String>> locales
      in _unchangedNaturalLanguageAllowlistByReason.values) {
    if (locales[locale]?.contains(location) ?? false) return true;
  }
  return false;
}

Map<String, int> _structuralDelimiterCounts(String value) {
  final Map<String, int> counts = <String, int>{};
  for (final String character in value.split('')) {
    if (!'[]{}<>|'.contains(character)) continue;
    counts[character] = (counts[character] ?? 0) + 1;
  }
  return counts;
}

bool _multisetsEqual(Map<String, int> left, Map<String, int> right) {
  if (left.length != right.length) return false;
  for (final MapEntry<String, int> entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

String _leadingWhitespace(String value) =>
    RegExp(r'^\s*').firstMatch(value)!.group(0)!;

String _trailingWhitespace(String value) =>
    RegExp(r'\s*$').firstMatch(value)!.group(0)!;

void _collectCalls(
  String source,
  Set<String> messages,
  Map<String, String> contexts,
  Map<String, Map<String, String>> plurals,
  String path,
) {
  for (final _Call call in _callsNamed(source, 'huiText')) {
    final _DartString? literal = _readAdjacentStrings(
      source,
      _skipTrivia(source, call.openParenthesis + 1),
    );
    if (literal == null) continue;
    if (literal.interpolated) {
      throw FormatException(
        'huiText must use a placeholder template, not interpolation, in $path.',
      );
    }
    _addMessage(messages, literal.value);
  }
  for (final _Call call in _callsNamed(source, 'huiTextKey')) {
    final _DartString? id = _readAdjacentStrings(
      source,
      _skipTrivia(source, call.openParenthesis + 1),
    );
    if (id == null || id.interpolated) {
      throw FormatException('huiTextKey must use a literal id in $path.');
    }
    final int comma = _skipTrivia(source, id.end);
    if (comma >= source.length || source[comma] != ',') {
      throw FormatException('huiTextKey is missing English text in $path.');
    }
    final _DartString? english = _readAdjacentStrings(
      source,
      _skipTrivia(source, comma + 1),
    );
    if (english == null || english.interpolated) {
      throw FormatException(
        'huiTextKey ${id.value} must use literal English text in $path.',
      );
    }
    final String? previous = contexts[id.value];
    if (previous != null && previous != english.value) {
      throw FormatException('Conflicting huiTextKey English for ${id.value}.');
    }
    contexts[id.value] = english.value;
  }
  for (final _Call call in _callsNamed(source, 'huiPlural')) {
    final int keyOffset = _skipTrivia(source, call.openParenthesis + 1);
    final _DartString? key = _readAdjacentStrings(source, keyOffset);
    if (key == null || key.interpolated) {
      final int argumentEnd = _firstArgumentEnd(
        source,
        keyOffset,
        call.closeParenthesis,
      );
      final String expression = source.substring(keyOffset, argumentEnd).trim();
      final bool explicitIssueRelay =
          (path.endsWith('${Platform.pathSeparator}validation.dart') &&
              expression == 'pluralKey') ||
          (path.endsWith('${Platform.pathSeparator}real_drop_script.dart') &&
              expression == 'key') ||
          (path.endsWith('${Platform.pathSeparator}workspace.dart') &&
              expression == 'key');
      if (explicitIssueRelay) continue;
      throw FormatException('huiPlural must use a literal key in $path.');
    }
    final Map<String, String> forms = <String, String>{};
    for (final String form in <String>[
      'zero',
      'one',
      'two',
      'few',
      'many',
      'other',
    ]) {
      final RegExpMatch? named = RegExp('\\b${form}English\\s*:').firstMatch(
        source.substring(call.openParenthesis + 1, call.closeParenthesis),
      );
      if (named == null) continue;
      final int valueOffset = call.openParenthesis + 1 + named.end;
      final _DartString? value = _readAdjacentStrings(
        source,
        _skipTrivia(source, valueOffset),
      );
      if (value == null || value.interpolated) {
        throw FormatException(
          '${form}English for ${key.value} must be a literal in $path.',
        );
      }
      forms[form] = value.value;
    }
    if (!forms.containsKey('one') || !forms.containsKey('other')) {
      throw FormatException(
        'huiPlural ${key.value} needs oneEnglish and otherEnglish in $path.',
      );
    }
    final Map<String, String>? previous = plurals[key.value];
    if (previous != null && !_mapsEqual(previous, forms)) {
      throw FormatException('Conflicting huiPlural defaults for ${key.value}.');
    }
    plurals[key.value] = forms;
  }
  _collectWorkspacePluralCalls(source, plurals, path);
  for (final String callName in <String>[
    'HuiIssue.plural',
    'RealDropScriptIssue.plural',
  ]) {
    _collectNamedPluralCalls(source, plurals, path, callName);
  }
}

void _collectWorkspacePluralCalls(
  String source,
  Map<String, Map<String, String>> plurals,
  String path,
) {
  if (!path.endsWith('${Platform.pathSeparator}workspace.dart')) return;
  for (final _Call call in _callsNamed(source, '_workspacePlural')) {
    final int keyOffset = _skipTrivia(source, call.openParenthesis + 1);
    final _DartString? key = _readAdjacentStrings(source, keyOffset);
    if (key == null || key.interpolated) {
      final int keyEnd = _firstArgumentEnd(
        source,
        keyOffset,
        call.closeParenthesis,
      );
      final String expression = source.substring(keyOffset, keyEnd).trim();
      if (expression == 'String key') continue;
      throw FormatException(
        '_workspacePlural must use a literal key in $path.',
      );
    }
    final Map<String, String> forms = <String, String>{};
    for (final String form in <String>[
      'zero',
      'one',
      'two',
      'few',
      'many',
      'other',
    ]) {
      final RegExpMatch? named = RegExp('\\b${form}English\\s*:').firstMatch(
        source.substring(call.openParenthesis + 1, call.closeParenthesis),
      );
      if (named == null) continue;
      final int valueOffset = call.openParenthesis + 1 + named.end;
      final _DartString? value = _readAdjacentStrings(
        source,
        _skipTrivia(source, valueOffset),
      );
      if (value == null || value.interpolated) {
        throw FormatException(
          '${form}English for ${key.value} must be a literal in $path.',
        );
      }
      forms[form] = value.value;
    }
    if (!forms.containsKey('one') || !forms.containsKey('other')) {
      throw FormatException(
        '_workspacePlural ${key.value} needs oneEnglish and otherEnglish '
        'in $path.',
      );
    }
    final Map<String, String>? previous = plurals[key.value];
    if (previous != null && !_mapsEqual(previous, forms)) {
      throw FormatException(
        'Conflicting _workspacePlural defaults for ${key.value}.',
      );
    }
    plurals[key.value] = forms;
  }
}

void _collectNamedPluralCalls(
  String source,
  Map<String, Map<String, String>> plurals,
  String path,
  String callName,
) {
  for (final _Call call in _callsNamed(source, callName)) {
    final String arguments = source.substring(
      call.openParenthesis + 1,
      call.closeParenthesis,
    );
    final RegExpMatch? keyArgument = RegExp(
      r'\bpluralKey\s*:',
    ).firstMatch(arguments);
    if (keyArgument == null) continue;
    final int keyOffset = _skipTrivia(
      source,
      call.openParenthesis + 1 + keyArgument.end,
    );
    final _DartString? key = _readAdjacentStrings(source, keyOffset);
    if (key == null || key.interpolated) {
      final int keyEnd = _firstArgumentEnd(
        source,
        keyOffset,
        call.closeParenthesis,
      );
      final String expression = source.substring(keyOffset, keyEnd).trim();
      if (callName == 'HuiIssue.plural' &&
          path.endsWith('${Platform.pathSeparator}real_drop_validation.dart') &&
          expression == 'pluralKey') {
        continue;
      }
      throw FormatException('$callName must use a literal pluralKey in $path.');
    }
    final Map<String, String> forms = <String, String>{};
    for (final String form in <String>[
      'zero',
      'one',
      'two',
      'few',
      'many',
      'other',
    ]) {
      final RegExpMatch? named = RegExp(
        '\\b${form}English\\s*:',
      ).firstMatch(arguments);
      if (named == null) continue;
      final _DartString? value = _readAdjacentStrings(
        source,
        _skipTrivia(source, call.openParenthesis + 1 + named.end),
      );
      if (value == null || value.interpolated) {
        throw FormatException(
          '${form}English for ${key.value} must be a literal in $path.',
        );
      }
      forms[form] = value.value;
    }
    if (!forms.containsKey('one') || !forms.containsKey('other')) {
      throw FormatException(
        '$callName ${key.value} needs oneEnglish and otherEnglish '
        'in $path.',
      );
    }
    final Map<String, String>? previous = plurals[key.value];
    if (previous != null && !_mapsEqual(previous, forms)) {
      throw FormatException('Conflicting $callName defaults for ${key.value}.');
    }
    plurals[key.value] = forms;
  }
}

void _collectSchema(
  GlossJsonNode node,
  Set<String> messages,
  Set<GlossJsonNode> visited,
) {
  if (!visited.add(node)) return;
  if (node is GlossJsonArray) {
    _addMessage(messages, node.itemTitle);
    _addMessage(messages, node.itemSummary);
    for (final GlossJsonValue value in node.itemValues) {
      _addMessage(messages, value.summary);
    }
    final GlossJsonNode? item = node.item;
    if (item != null) _collectSchema(item, messages, visited);
    return;
  }
  final GlossJsonObject object = node as GlossJsonObject;
  _addMessage(messages, object.openKeyTitle);
  _addMessage(messages, object.openKeySummary);
  for (final GlossJsonField field in object.fields) {
    _collectSchemaField(field, messages, visited);
  }
  for (final List<GlossJsonField> fields in object.variants.values) {
    for (final GlossJsonField field in fields) {
      _collectSchemaField(field, messages, visited);
    }
  }
}

void _collectSchemaField(
  GlossJsonField field,
  Set<String> messages,
  Set<GlossJsonNode> visited,
) {
  _addMessage(messages, field.title);
  _addMessage(messages, field.summary);
  for (final GlossJsonValue value in field.values) {
    _addMessage(messages, value.summary);
  }
  final GlossJsonNode? child = field.node;
  if (child != null) _collectSchema(child, messages, visited);
}

void _collectFiniteDartMetadata(Directory root, Set<String> messages) {
  final List<String> paths = <String>[
    '${root.path}/lib/config/defaults.dart',
    '${root.path}/lib/config/links.dart',
    '${root.path}/lib/logic/preview_sim_controls.dart',
    '${root.path}/lib/components/canvas/canvas_viewport.dart',
    '${root.path}/lib/components/dialogs/help_dialog.dart',
    '${root.path}/lib/components/shell/tour.dart',
    '${root.path}/lib/components/inspector/text_icon_editor.dart',
    '${root.path}/lib/components/preview/preview_toolbar.dart',
  ];
  final Directory doctype = Directory('${root.path}/lib/doctype');
  for (final FileSystemEntity entity in doctype.listSync()) {
    if (entity is File && entity.path.endsWith('_document_type.dart')) {
      paths.add(entity.path);
    }
  }
  for (final String path in paths) {
    final String source = File(path).readAsStringSync();
    _collectNamedString(source, messages, <String>{
      'title',
      'body',
      'hint',
      'label',
      'name',
      'description',
      'note',
      'idFormat',
    });
    _collectNamedStringLists(source, messages, <String>{'highlights'});
    _collectGetterStrings(source, messages, <String>{
      'noun',
      'createLabel',
      'pluralLabel',
      'surfaceLabel',
      'contentsTabLabel',
      'templatesTabLabel',
      'templatesNote',
      'codeShapeError',
    });
    if (path.endsWith('${Platform.pathSeparator}defaults.dart')) {
      for (final String name in <String>[
        'huiComponentTypeDescriptions',
        'huiIconTypeDescriptions',
        'previewElementTypeDescriptions',
      ]) {
        _collectStringMapValues(source, messages, name);
      }
    }
    if (path.endsWith('${Platform.pathSeparator}preview_sim_controls.dart')) {
      _collectStringMapValues(source, messages, '_varLabels');
      _collectStringMapValues(source, messages, '_categoryLabels');
    }
    if (path.endsWith('${Platform.pathSeparator}canvas_viewport.dart')) {
      _collectAssignedString(source, messages, <String>{
        'huiDragHint',
        'huiHitboxDragHint',
        'huiMarqueeHint',
      });
    }
    if (path.endsWith('${Platform.pathSeparator}help_dialog.dart')) {
      _collectStringCollectionInitializer(source, messages, '_nonFeatureList');
    }
  }
}

void _collectStringMapValues(String source, Set<String> messages, String name) {
  final RegExpMatch? declaration = RegExp('\\b$name\\s*=').firstMatch(source);
  if (declaration == null) return;
  final int open = source.indexOf('{', declaration.end);
  if (open < 0) return;
  final int close = _matchingDelimiter(source, open, '{', '}');
  if (close < 0) return;
  int cursor = open + 1;
  while (cursor < close) {
    cursor = _skipTrivia(source, cursor);
    final _DartString? key = _readAdjacentStrings(source, cursor);
    if (key == null) {
      cursor++;
      continue;
    }
    cursor = _skipTrivia(source, key.end);
    if (cursor >= close || source[cursor] != ':') {
      cursor = key.end;
      continue;
    }
    cursor = _skipTrivia(source, cursor + 1);
    final _DartString? value = _readAdjacentStrings(source, cursor);
    if (value == null) continue;
    if (!value.interpolated) _addMessage(messages, value.value);
    cursor = value.end;
  }
}

void _collectNamedString(
  String source,
  Set<String> messages,
  Set<String> names,
) {
  final RegExp pattern = RegExp('\\b(${names.join('|')})\\s*:');
  for (final RegExpMatch match in pattern.allMatches(source)) {
    final _DartString? literal = _readAdjacentStrings(
      source,
      _skipTrivia(source, match.end),
    );
    if (literal != null && !literal.interpolated) {
      _addMessage(messages, literal.value);
    }
  }
}

void _collectNamedStringLists(
  String source,
  Set<String> messages,
  Set<String> names,
) {
  final RegExp pattern = RegExp('\\b(${names.join('|')})\\s*:');
  for (final RegExpMatch match in pattern.allMatches(source)) {
    int cursor = _skipTrivia(source, match.end);
    final int bracket = source.indexOf('[', cursor);
    if (bracket < 0 || bracket - cursor > 80) continue;
    final int close = _matchingDelimiter(source, bracket, '[', ']');
    if (close < 0) continue;
    cursor = bracket + 1;
    while (cursor < close) {
      final _DartString? literal = _readAdjacentStrings(
        source,
        _skipTrivia(source, cursor),
      );
      if (literal == null) {
        cursor++;
        continue;
      }
      if (!literal.interpolated) _addMessage(messages, literal.value);
      cursor = literal.end;
    }
  }
}

void _collectGetterStrings(
  String source,
  Set<String> messages,
  Set<String> names,
) {
  final RegExp pattern = RegExp(
    'String\\??\\s+get\\s+(${names.join('|')})\\s*=>',
  );
  for (final RegExpMatch match in pattern.allMatches(source)) {
    final _DartString? literal = _readAdjacentStrings(
      source,
      _skipTrivia(source, match.end),
    );
    if (literal != null && !literal.interpolated) {
      _addMessage(messages, literal.value);
    }
  }
}

void _collectPreviewVariableDescriptions(Directory root, Set<String> messages) {
  final File file = File(
    '${root.path}/web/assets/catalog/preview-variables.json',
  );
  final Object? decoded = jsonDecode(file.readAsStringSync());
  void visit(Object? value) {
    if (value is List<Object?>) {
      for (final Object? item in value) {
        visit(item);
      }
      return;
    }
    if (value is! Map<String, Object?>) return;
    final Object? description = value['description'];
    if (description is String) _addMessage(messages, description);
    for (final Object? child in value.values) {
      visit(child);
    }
  }

  visit(decoded);
}

Map<String, String> _readEnglishPreviewMessages(Directory root) {
  final File file = File(
    '${root.path}/web/assets/catalog/preview-lang-en.json',
  );
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException('${file.path} must contain an object.');
  }
  return _stringMap(decoded['messages']);
}

Iterable<_Call> _callsNamed(String source, String name) sync* {
  final RegExp pattern = RegExp('\\b${RegExp.escape(name)}\\s*\\(');
  for (final RegExpMatch match in pattern.allMatches(source)) {
    final int open = source.indexOf('(', match.start);
    final int close = _matchingDelimiter(source, open, '(', ')');
    if (close >= 0) yield _Call(open, close);
  }
}

Iterable<_Call> _thrownCallsNamed(String source, String name) sync* {
  final RegExp pattern = RegExp('\\bthrow\\s+(?:const\\s+)?$name\\s*\\(');
  for (final RegExpMatch match in pattern.allMatches(source)) {
    final int open = source.indexOf('(', match.start);
    final int close = _matchingDelimiter(source, open, '(', ')');
    if (close >= 0) yield _Call(open, close);
  }
}

int _matchingDelimiter(
  String source,
  int open,
  String openCharacter,
  String closeCharacter,
) {
  int depth = 0;
  int cursor = open;
  while (cursor < source.length) {
    final _DartString? literal = _readString(source, cursor);
    if (literal != null) {
      cursor = literal.end;
      continue;
    }
    if (source.startsWith('//', cursor)) {
      final int newline = source.indexOf('\n', cursor + 2);
      cursor = newline < 0 ? source.length : newline + 1;
      continue;
    }
    if (source.startsWith('/*', cursor)) {
      final int end = source.indexOf('*/', cursor + 2);
      cursor = end < 0 ? source.length : end + 2;
      continue;
    }
    final String character = source[cursor];
    if (character == openCharacter) depth++;
    if (character == closeCharacter) {
      depth--;
      if (depth == 0) return cursor;
    }
    cursor++;
  }
  return -1;
}

_DartString? _readAdjacentStrings(String source, int offset) {
  _DartString? first = _readString(source, offset);
  if (first == null) return null;
  final StringBuffer value = StringBuffer(first.value);
  bool interpolated = first.interpolated;
  int end = first.end;
  while (true) {
    final int nextOffset = _skipTrivia(source, end);
    final _DartString? next = _readString(source, nextOffset);
    if (next == null) break;
    value.write(next.value);
    interpolated = interpolated || next.interpolated;
    end = next.end;
  }
  return _DartString(value.toString(), end, interpolated);
}

_DartString? _readString(String source, int offset) {
  if (offset >= source.length) return null;
  int cursor = offset;
  bool raw = false;
  if ((source[cursor] == 'r' || source[cursor] == 'R') &&
      cursor + 1 < source.length &&
      (source[cursor + 1] == "'" || source[cursor + 1] == '"')) {
    raw = true;
    cursor++;
  }
  if (source[cursor] != "'" && source[cursor] != '"') return null;
  final String quote = source[cursor];
  final bool triple = source.startsWith(quote * 3, cursor);
  final int delimiterLength = triple ? 3 : 1;
  cursor += delimiterLength;
  final StringBuffer value = StringBuffer();
  bool interpolated = false;
  while (cursor < source.length) {
    if (source.startsWith(quote * delimiterLength, cursor)) {
      return _DartString(
        value.toString(),
        cursor + delimiterLength,
        interpolated,
      );
    }
    final String character = source[cursor];
    if (!raw && character == r'\') {
      if (cursor + 1 >= source.length) break;
      final String escaped = source[cursor + 1];
      final Map<String, String> simple = <String, String>{
        'n': '\n',
        'r': '\r',
        't': '\t',
        'b': '\b',
        'f': '\f',
        'v': '\u000b',
        r'\': r'\',
        "'": "'",
        '"': '"',
        r'$': r'$',
      };
      if (simple.containsKey(escaped)) {
        value.write(simple[escaped]);
        cursor += 2;
        continue;
      }
      if (escaped == 'u' || escaped == 'x') {
        final _Escape? codePoint = _readCodePointEscape(source, cursor);
        if (codePoint != null) {
          value.write(String.fromCharCode(codePoint.codePoint));
          cursor = codePoint.end;
          continue;
        }
      }
      value.write(escaped);
      cursor += 2;
      continue;
    }
    if (!raw && character == r'$') interpolated = true;
    value.write(character);
    cursor++;
  }
  return null;
}

_Escape? _readCodePointEscape(String source, int slash) {
  final String kind = source[slash + 1];
  if (kind == 'x' && slash + 4 <= source.length) {
    final String digits = source.substring(slash + 2, slash + 4);
    final int? value = int.tryParse(digits, radix: 16);
    return value == null ? null : _Escape(value, slash + 4);
  }
  if (kind != 'u') return null;
  if (slash + 3 < source.length && source[slash + 2] == '{') {
    final int close = source.indexOf('}', slash + 3);
    if (close < 0) return null;
    final int? value = int.tryParse(
      source.substring(slash + 3, close),
      radix: 16,
    );
    return value == null ? null : _Escape(value, close + 1);
  }
  if (slash + 6 > source.length) return null;
  final int? value = int.tryParse(
    source.substring(slash + 2, slash + 6),
    radix: 16,
  );
  return value == null ? null : _Escape(value, slash + 6);
}

int _skipTrivia(String source, int offset) {
  int cursor = offset;
  while (cursor < source.length) {
    if (RegExp(r'\s').hasMatch(source[cursor])) {
      cursor++;
      continue;
    }
    if (source.startsWith('//', cursor)) {
      final int newline = source.indexOf('\n', cursor + 2);
      cursor = newline < 0 ? source.length : newline + 1;
      continue;
    }
    if (source.startsWith('/*', cursor)) {
      final int end = source.indexOf('*/', cursor + 2);
      cursor = end < 0 ? source.length : end + 2;
      continue;
    }
    break;
  }
  return cursor;
}

void _addMessage(Set<String> messages, String? value) {
  if (value == null) return;
  if (value.trim().isNotEmpty) messages.add(value);
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected an object of strings.');
  }
  return <String, String>{
    for (final MapEntry<String, Object?> entry in value.entries)
      entry.key: entry.value as String,
  };
}

Map<String, Map<String, String>> _pluralMap(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected a plural object.');
  }
  return <String, Map<String, String>>{
    for (final MapEntry<String, Object?> entry in value.entries)
      entry.key: _stringMap(entry.value),
  };
}

Map<String, String> _sortedStringMap(Map<String, String> values) =>
    <String, String>{
      for (final String key in values.keys.toList()..sort()) key: values[key]!,
    };

bool _mapsEqual(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) return false;
  for (final MapEntry<String, String> entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

final class _Call {
  const _Call(this.openParenthesis, this.closeParenthesis);

  final int openParenthesis;
  final int closeParenthesis;
}

final class _DartString {
  const _DartString(this.value, this.end, this.interpolated);

  final String value;
  final int end;
  final bool interpolated;
}

final class _Escape {
  const _Escape(this.codePoint, this.end);

  final int codePoint;
  final int end;
}
