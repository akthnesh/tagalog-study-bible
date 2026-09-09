import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../models/bible_book.dart';
import '../models/bible_chapter.dart';
import '../models/bible_verse.dart';

class BibleXmlService {
  static const _translationPaths = {
    'ABTAG': 'assets/bible/ABTAG2001_Main_Translation.xml',
    'ESV': 'assets/bible/ESV.xml',
    'NKJV': 'assets/bible/NKJV.xml',
    'NIV': 'assets/bible/NIV.xml',
    'LSB': 'assets/bible/LSB.xml',
    'NASB': 'assets/bible/NASB.xml',
  };

  static const translationNames = {
    'ABTAG': 'Ang Biblia, 2001',
    'ESV': 'English Standard Version',
    'NKJV': 'New King James Version',
    'NIV': 'New International Version',
    'NASB': 'New American Standard Bible',
    'LSB': 'Legacy Standard Bible',
  };

  final Map<String, List<BibleBook>> _cache = {};

  /// Load the default (ABTAG) translation.
  Future<List<BibleBook>> loadBible() => loadTranslation('ABTAG');

  /// Load a specific translation by ID.
  Future<List<BibleBook>> loadTranslation(String translationId) async {
    if (_cache.containsKey(translationId)) {
      return _cache[translationId]!;
    }

    final path = _translationPaths[translationId];
    if (path == null) {
      return const <BibleBook>[];
    }

    try {
      final xmlText = await rootBundle.loadString(path);
      final document = XmlDocument.parse(xmlText);

      // findAllElements bypasses extra wrappers like <testament>
      final bookElements = document.findAllElements('book').toList();

      final books = <BibleBook>[];
      for (var b = 0; b < bookElements.length; b++) {
        books.add(_parseBook(bookElements[b], b + 1));
      }

      _cache[translationId] = books;
      return books;
    } catch (e) {
      return const <BibleBook>[];
    }
  }

  BibleBook _parseBook(XmlElement element, int bookIndex) {
    final chapterElements = element.findAllElements('chapter').toList();
    final chapters = <BibleChapter>[];
    for (var c = 0; c < chapterElements.length; c++) {
      chapters.add(_parseChapter(chapterElements[c], c + 1));
    }

    return BibleBook(
      number: _intAttr(element, 'number', fallback: bookIndex),
      osis: element.getAttribute('osis') ?? '',
      name: element.getAttribute('name') ?? '',
      chapterCount: _intAttr(element, 'chapters', fallback: chapters.length),
      chapters: chapters,
    );
  }

  BibleChapter _parseChapter(XmlElement element, int chapterIndex) {
    final title = element.getElement('title')?.innerText.trim();
    final verseElements = element.findAllElements('verse').toList();
    final verses = <BibleVerse>[];
    for (var v = 0; v < verseElements.length; v++) {
      verses.add(BibleVerse(
        number: _intAttr(verseElements[v], 'number', fallback: v + 1),
        osis: verseElements[v].getAttribute('osis') ?? '',
        text: verseElements[v].innerText.trim(),
      ));
    }

    return BibleChapter(
      number: _intAttr(element, 'number', fallback: chapterIndex),
      osis: element.getAttribute('osis') ?? '',
      name: element.getAttribute('name') ?? '',
      title: title?.isEmpty == true ? null : title,
      verses: verses,
    );
  }

  int _intAttr(XmlElement element, String name, {int fallback = 0}) {
    return int.tryParse(element.getAttribute(name) ?? '') ?? fallback;
  }
}
