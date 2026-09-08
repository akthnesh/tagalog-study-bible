import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../models/bible_book.dart';
import '../models/bible_chapter.dart';
import '../models/bible_verse.dart';

class BibleXmlService {
  static const assetPath = 'assets/bible/ABTAG2001_Main_Translation.xml';

  Future<List<BibleBook>> loadBible() async {
    final xmlText = await rootBundle.loadString(assetPath);
    final document = XmlDocument.parse(xmlText);
    final root = document.rootElement;

    return root
        .findElements('book')
        .map(_parseBook)
        .toList(growable: false);
  }

  BibleBook _parseBook(XmlElement element) {
    final chapters = element
        .findElements('chapter')
        .map(_parseChapter)
        .toList(growable: false);

    return BibleBook(
      number: _intAttr(element, 'number'),
      osis: element.getAttribute('osis') ?? '',
      name: element.getAttribute('name') ?? '',
      chapterCount: _intAttr(element, 'chapters', fallback: chapters.length),
      chapters: chapters,
    );
  }

  BibleChapter _parseChapter(XmlElement element) {
    final title = element.getElement('title')?.innerText.trim();
    final verses = element
        .findElements('verse')
        .map((verse) => BibleVerse(
              number: _intAttr(verse, 'number'),
              osis: verse.getAttribute('osis') ?? '',
              text: verse.innerText.trim(),
            ))
        .toList(growable: false);

    return BibleChapter(
      number: _intAttr(element, 'number'),
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
