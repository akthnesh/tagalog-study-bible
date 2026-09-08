import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'models/bible_book.dart';
import 'models/bible_chapter.dart';
import 'models/bible_verse.dart';
import 'services/bible_xml_service.dart';

const _bg = Color(0xFF202020);
const _panel = Color(0xFF171717);
const _panel2 = Color(0xFF1D1D1D);
const _line = Color(0xFF343434);
const _text = Color(0xFFF4F1EA);
const _muted = Color(0xFFB7B2AA);
const _gold = Color(0xFFE6C229);

void main() => runApp(const TagalogStudyBibleApp());

class TagalogStudyBibleApp extends StatelessWidget {
  const TagalogStudyBibleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tagalog Study Bible',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _bg,
          colorScheme: const ColorScheme.dark(primary: _gold),
          fontFamily: 'Georgia',
        ),
        home: const BibleShell(),
      );
}

class BibleShell extends StatefulWidget {
  const BibleShell({super.key});

  @override
  State<BibleShell> createState() => BibleShellState();
}

class BibleShellState extends State<BibleShell> {
  final BibleXmlService _bibleService = BibleXmlService();
  late Future<List<BibleBook>> _bibleFuture;

  int selectedBookIndex = 0;
  int selectedChapterIndex = 0;
  int selectedVerse = -1;

  bool books = true;
  bool study = true;

  @override
  void initState() {
    super.initState();
    _bibleFuture = _bibleService.loadBible();
  }

  BibleBook? _bookAt(List<BibleBook> bible, int index) =>
      index >= 0 && index < bible.length ? bible[index] : null;

  BibleChapter? _chapterAt(BibleBook book, int index) =>
      index >= 0 && index < book.chapters.length ? book.chapters[index] : null;

  void _selectBook(int index) => setState(() {
        selectedBookIndex = index;
        selectedChapterIndex = 0;
        selectedVerse = 1;
      });

  void _selectChapter(int index) => setState(() {
        selectedChapterIndex = index;
        selectedVerse = 1;
      });

  void _goChapter(List<BibleBook> bible, int direction) {
    if (bible.isEmpty) return;
    var bookIndex = selectedBookIndex;
    var chapterIndex = selectedChapterIndex + direction;

    if (direction < 0 && chapterIndex < 0) {
      if (bookIndex == 0) return;
      do {
        bookIndex--;
      } while (bookIndex >= 0 && bible[bookIndex].chapters.isEmpty);
      if (bookIndex < 0) return;
      chapterIndex = bible[bookIndex].chapters.length - 1;
    }

    if (direction > 0 && chapterIndex >= bible[bookIndex].chapters.length) {
      do {
        bookIndex++;
      } while (bookIndex < bible.length && bible[bookIndex].chapters.isEmpty);
      if (bookIndex >= bible.length) return;
      chapterIndex = 0;
    }

    if (bookIndex < 0 || bookIndex >= bible.length) return;
    if (chapterIndex < 0 || chapterIndex >= bible[bookIndex].chapters.length) return;

    setState(() {
      selectedBookIndex = bookIndex;
      selectedChapterIndex = chapterIndex;
      selectedVerse = 1;
    });
  }

  void _showChapterPicker(BuildContext context, BibleBook book) {
    showDialog<void>(
      context: context,
      builder: (_) => _ChapterPickerDialog(
        book: book,
        selectedIndex: selectedChapterIndex,
        onSelected: (index) {
          Navigator.of(context).pop();
          _selectChapter(index);
        },
      ),
    );
  }

  void _showBookPicker(BuildContext context, List<BibleBook> bible) {
    showDialog<void>(
      context: context,
      builder: (_) => _BookPickerDialog(
        books: bible,
        selectedIndex: selectedBookIndex,
        onSelected: (index) {
          Navigator.of(context).pop();
          _selectBook(index);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: FutureBuilder<List<BibleBook>>(
            future: _bibleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingScreen();
              }
              if (snapshot.hasError) {
                return _ErrorScreen(
                  error: snapshot.error,
                  onRetry: () => setState(() {
                    _bibleFuture = _bibleService.loadBible();
                  }),
                );
              }

              final bible = snapshot.data ?? const <BibleBook>[];
              final book = _bookAt(bible, selectedBookIndex);
              if (book == null) {
                return const _ErrorScreen(message: 'Walang laman ang Bible data.');
              }
              final chapter = _chapterAt(book, selectedChapterIndex);
              if (chapter == null) {
                return const _ErrorScreen(
                  message: 'Walang chapter data para sa napiling aklat.',
                );
              }

              if (selectedVerse > 0 && !chapter.verses.any((v) => v.number == selectedVerse)) {
                selectedVerse = chapter.verses.isEmpty ? -1 : chapter.verses.first.number;
              }

              final width = MediaQuery.sizeOf(context).width;
              final mobile = width < 900;
              final narrowDesktop = width < 1250;

              return Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (books && !mobile)
                          SizedBox(
                            width: narrowDesktop ? 255 : 315,
                            child: _BookPanel(
                              books: bible,
                              selectedIndex: selectedBookIndex,
                              onSelected: _selectBook,
                              onCollapse: () => setState(() => books = false),
                            ),
                          ),
                        Expanded(
                          child: _Reader(
                            book: book,
                            chapter: chapter,
                            selectedVerse: selectedVerse,
                            onSelected: (verse) =>
                                setState(() => selectedVerse = verse),
                            onDeselect: () =>
                                setState(() => selectedVerse = -1),
                            onPreviousChapter: () => _goChapter(bible, -1),
                            onNextChapter: () => _goChapter(bible, 1),
                            onChapterPicker: () =>
                                _showChapterPicker(context, book),
                            onBooks: () => mobile
                                ? _showBookPicker(context, bible)
                                : setState(() => books = !books),
                            onStudy: () => setState(() => study = !study),
                            showBooksButton: mobile || !books,
                          ),
                        ),
                        if (study && !mobile)
                          SizedBox(
                            width: narrowDesktop ? 320 : 315,
                            child: _StudyPanel(
                              book: book,
                              chapter: chapter,
                              verse: selectedVerse,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (mobile)
                    _MobileBar(
                      onBooks: () => _showBookPicker(context, bible),
                      onStudy: () => setState(() => study = !study),
                    ),
                ],
              );
            },
          ),
        ),
      );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: _gold),
      );
}

class _ErrorScreen extends StatelessWidget {
  final Object? error;
  final String? message;
  final VoidCallback? onRetry;
  const _ErrorScreen({this.error, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _gold, size: 42),
              const SizedBox(height: 14),
              Text(message ?? 'Hindi ma-load ang Bible XML.', textAlign: TextAlign.center),
              if (error != null) ...[
                const SizedBox(height: 10),
                SelectableText('$error', textAlign: TextAlign.center),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      );
}

class _BookPanel extends StatelessWidget {
  final List<BibleBook> books;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onCollapse;

  const _BookPanel({
    required this.books,
    required this.selectedIndex,
    required this.onSelected,
    required this.onCollapse,
  });

  static const _otGroups = <String, List<int>>{
    'The Pentateuch': [1, 2, 3, 4, 5],
    'Historical Books': [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    'Poetry and Wisdom\nLiterature': [18, 19, 20, 21, 22],
    'Major Prophets': [23, 24, 25, 26, 27],
    'Minor Prophets': [28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39],
  };

  static const _ntGroups = <String, List<int>>{
    'The Gospels': [40, 41, 42, 43],
    'Church History': [44],
    'Pauline Epistles': [45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57],
    'General Epistles': [58, 59, 60, 61, 62, 63, 64, 65],
    'Prophecy': [66],
  };

  @override
  Widget build(BuildContext context) {
    final byNumber = {for (final b in books) b.number: b};
    return Container(
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(right: BorderSide(color: _line)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(38, 25, 8, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'TABLE OF CONTENTS',
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onCollapse,
                  icon: const Icon(Icons.keyboard_double_arrow_left, size: 18),
                  tooltip: 'Hide table of contents',
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(38, 8, 8, 25),
                    children: [
                      const Text('OLD TESTAMENT', style: TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 18),
                      _BookGroups(
                        groups: _otGroups,
                        byNumber: byNumber,
                        books: books,
                        selectedIndex: selectedIndex,
                        onSelected: onSelected,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(6, 8, 25, 25),
                    children: [
                      const Text('NEW TESTAMENT', style: TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 18),
                      _BookGroups(
                        groups: _ntGroups,
                        byNumber: byNumber,
                        books: books,
                        selectedIndex: selectedIndex,
                        onSelected: onSelected,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _BottomLinks(),
        ],
      ),
    );
  }
}

class _BookGroups extends StatelessWidget {
  final Map<String, List<int>> groups;
  final Map<int, BibleBook> byNumber;
  final List<BibleBook> books;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _BookGroups({
    required this.groups,
    required this.byNumber,
    required this.books,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: groups.entries.map((entry) {
            final items = entry.value
                .map((n) => byNumber[n])
                .whereType<BibleBook>()
                .toList();
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...items.map((book) {
                    final index = books.indexOf(book);
                    final active = index == selectedIndex;
                    return InkWell(
                      onTap: () => onSelected(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                          book.name,
                          style: TextStyle(
                            color: active ? _gold : _text,
                            fontSize: 13.5,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }).toList(),
        ),
      );
}

class _BottomLinks extends StatelessWidget {
  const _BottomLinks();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(38, 0, 25, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('BOOK INTRODUCTIONS', style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('THEOLOGY', style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('DOCTRINES', style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 22),
            Row(
              children: [
                Text('Login', style: TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(width: 28),
                Text('A+', style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(width: 12),
                Text('A-', style: TextStyle(color: _muted, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      );
}

class _Reader extends StatefulWidget {
  final BibleBook book;
  final BibleChapter chapter;
  final int selectedVerse;
  final ValueChanged<int> onSelected;
  final VoidCallback onDeselect;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onChapterPicker;
  final VoidCallback onBooks;
  final VoidCallback onStudy;
  final bool showBooksButton;

  const _Reader({
    required this.book,
    required this.chapter,
    required this.selectedVerse,
    required this.onSelected,
    required this.onDeselect,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onChapterPicker,
    required this.onBooks,
    required this.onStudy,
    required this.showBooksButton,
  });

  @override
  State<_Reader> createState() => _ReaderState();
}

class _ReaderState extends State<_Reader> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        color: _bg,
        child: Column(
          children: [
            _ReaderToolbar(
              onBooks: widget.onBooks,
              onStudy: widget.onStudy,
              showBooksButton: widget.showBooksButton,
            ),
            Container(
              height: 55,
              decoration: const BoxDecoration(
                color: _panel2,
                border: Border(bottom: BorderSide(color: _line)),
              ),
              child: Row(
                children: [
                  IconButton(onPressed: widget.onPreviousChapter, icon: const Icon(Icons.chevron_left, size: 30)),
                  Expanded(
                    child: Center(
                      child: InkWell(
                        onTap: widget.onChapterPicker,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            '${widget.book.name} ${widget.chapter.number}',
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(onPressed: widget.onNextChapter, icon: const Icon(Icons.chevron_right, size: 30)),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(60, 32, 60, 0),
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onDeselect,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.book.name} ${widget.chapter.number}',
                            style: const TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text('Ang Biblia, 2001', style: TextStyle(color: _muted, fontSize: 13)),
                          if (widget.chapter.title != null) ...[
                            const SizedBox(height: 20),
                            Text(
                              widget.chapter.title!,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ],
                          const SizedBox(height: 22),
                          _BibleParagraphs(
                            verses: widget.chapter.verses,
                            selectedVerse: widget.selectedVerse,
                            onSelected: widget.onSelected,
                          ),
                          const SizedBox(height: 200),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _ReaderToolbar extends StatelessWidget {
  final VoidCallback onBooks, onStudy;
  final bool showBooksButton;
  const _ReaderToolbar({
    required this.onBooks,
    required this.onStudy,
    required this.showBooksButton,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 75,
        child: Row(
          children: [
            if (showBooksButton)
              IconButton(
                onPressed: onBooks,
                icon: const Icon(Icons.menu_book_outlined),
                tooltip: 'Table of contents',
              ),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 235,
                    height: 42,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search',
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: _muted),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: _gold),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const _TranslationButton('ABTAG', active: true),
                  const SizedBox(width: 8),
                  const _TranslationButton('ESV'),
                  const SizedBox(width: 8),
                  const _TranslationButton('NKJV'),
                ],
              ),
            ),
            IconButton(onPressed: onStudy, icon: const Icon(Icons.view_sidebar_outlined), tooltip: 'Study panel'),
          ],
        ),
      );
}

class _TranslationButton extends StatelessWidget {
  final String label;
  final bool active;
  const _TranslationButton(this.label, {this.active = false});
  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF121212) : const Color(0xFF181818),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      );
}

class _BibleParagraphs extends StatelessWidget {
  final List<BibleVerse> verses;
  final int selectedVerse;
  final ValueChanged<int> onSelected;

  const _BibleParagraphs({
    required this.verses,
    required this.selectedVerse,
    required this.onSelected,
  });

  List<List<BibleVerse>> _paragraphs() {
    final result = <List<BibleVerse>>[];
    var current = <BibleVerse>[];
    for (var i = 0; i < verses.length; i++) {
      current.add(verses[i]);
      if (i == verses.length - 1 || (i + 1) % 5 == 0) {
        result.add(current);
        current = <BibleVerse>[];
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paragraph in _paragraphs())
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _BibleParagraphText(
                verses: paragraph,
                selectedVerse: selectedVerse,
                onSelected: onSelected,
              ),
            ),
        ],
      );
}

class _BibleParagraphText extends StatefulWidget {
  final List<BibleVerse> verses;
  final int selectedVerse;
  final ValueChanged<int> onSelected;
  const _BibleParagraphText({
    required this.verses,
    required this.selectedVerse,
    required this.onSelected,
  });

  @override
  State<_BibleParagraphText> createState() => _BibleParagraphTextState();
}

class _BibleParagraphTextState extends State<_BibleParagraphText> {
  late List<TapGestureRecognizer> _recognizers;

  @override
  void initState() {
    super.initState();
    _makeRecognizers();
  }

  void _makeRecognizers() {
    _recognizers = widget.verses
        .map((verse) => TapGestureRecognizer()..onTap = () => widget.onSelected(verse.number))
        .toList();
  }

  @override
  void didUpdateWidget(covariant _BibleParagraphText oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _makeRecognizers();
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    for (var i = 0; i < widget.verses.length; i++) {
      final verse = widget.verses[i];
      final selected = verse.number == widget.selectedVerse;
      spans.add(
        TextSpan(
          text: '${verse.number} ',
          recognizer: _recognizers[i],
          style: TextStyle(
            color: selected ? Colors.black : _gold,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            backgroundColor: selected ? const Color(0xFFE6C229) : null,
          ),
        ),
      );
      spans.add(
        TextSpan(
          text: '${verse.text} ',
          recognizer: _recognizers[i],
          style: TextStyle(
            color: selected ? Colors.black : _text,
            fontSize: 16,
            height: 1.48,
            backgroundColor: selected ? const Color(0xFFE6C229) : null,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.justify,
    );
  }
}

class _StudyPanel extends StatelessWidget {
  final BibleBook book;
  final BibleChapter chapter;
  final int verse;

  const _StudyPanel({
    required this.book,
    required this.chapter,
    required this.verse,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = verse > 0;
    final selected = hasSelection
        ? chapter.verses.where((v) => v.number == verse).firstOrNull
        : null;
    return Container(
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(left: BorderSide(color: _line)),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(15, 8, 15, 45),
          children: [
            const Text(
              'Notes and Cross References',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(
              hasSelection
                  ? '${book.name} ${chapter.number}:$verse'
                  : '${book.name} ${chapter.number}',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
            const SizedBox(height: 15),
            if (!hasSelection) ...[
              const SizedBox(height: 30),
              const Center(
                child: Icon(Icons.touch_app_outlined, size: 40, color: _muted),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Select a verse to view notes\nand cross references.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
                ),
              ),
            ],
            if (hasSelection && selected != null)
              Text(
                selected.text,
                style: const TextStyle(
                  color: _text,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (hasSelection) ...[
              const SizedBox(height: 20),
              const _StudySection(
                title: 'Cross References',
                child: Text(
                  'Cross references connected to this passage will appear here.',
                  style: TextStyle(color: _text, fontSize: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 22),
              _StudySection(
                title: 'Exegetical Notes on ${book.name} ${chapter.number}:$verse',
                child: const Text(
                  'Exegetical observations, contextual notes, and source-linked study material will appear here.',
                  style: TextStyle(color: _text, fontSize: 13, height: 1.48),
                ),
              ),
              const SizedBox(height: 22),
              const _StudySection(
                title: 'Hebrew Text',
                child: Text(
                  'Hebrew text will appear here when the original-language resource is connected.',
                  style: TextStyle(color: _text, fontSize: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 22),
              const _StudySection(
                title: 'Transliteration',
                child: Text(
                  'Original-language transliteration will appear here.',
                  style: TextStyle(color: _text, fontSize: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 22),
              const _StudySection(
                title: 'Literal rendering',
                child: Text(
                  'A literal rendering and word-level observations will appear here.',
                  style: TextStyle(color: _text, fontSize: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 22),
              const _StudySection(
                title: 'Exegetical observation',
                child: Text(
                  'Detailed observations will be linked to the selected verse as the study corpus is integrated.',
                  style: TextStyle(color: _text, fontSize: 13, height: 1.45),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudySection extends StatelessWidget {
  final String title;
  final Widget child;
  const _StudySection({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          child,
          const SizedBox(height: 10),
          const Divider(color: _line),
        ],
      );
}

class _MobileBar extends StatelessWidget {
  final VoidCallback onBooks, onStudy;
  const _MobileBar({required this.onBooks, required this.onStudy});
  @override
  Widget build(BuildContext context) => Container(
        height: 54,
        color: _panel,
        child: Row(
          children: [
            Expanded(child: TextButton.icon(onPressed: onBooks, icon: const Icon(Icons.menu_book), label: const Text('Books'))),
            Expanded(child: TextButton.icon(onPressed: onStudy, icon: const Icon(Icons.view_sidebar), label: const Text('Study'))),
          ],
        ),
      );
}

class _ChapterPickerDialog extends StatelessWidget {
  final BibleBook book;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _ChapterPickerDialog({required this.book, required this.selectedIndex, required this.onSelected});
  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: _panel,
        title: Text(book.name),
        content: SizedBox(
          width: 440,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: book.chapters.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.3,
            ),
            itemBuilder: (_, index) => InkWell(
              onTap: () => onSelected(index),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: index == selectedIndex ? _gold : _panel2,
                  border: Border.all(color: _line),
                ),
                child: Text(
                  '${book.chapters[index].number}',
                  style: TextStyle(color: index == selectedIndex ? Colors.black : _text),
                ),
              ),
            ),
          ),
        ),
      );
}

class _BookPickerDialog extends StatelessWidget {
  final List<BibleBook> books;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _BookPickerDialog({required this.books, required this.selectedIndex, required this.onSelected});
  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Table of Contents'),
        content: SizedBox(
          width: 500,
          height: 550,
          child: ListView.builder(
            itemCount: books.length,
            itemBuilder: (_, index) => ListTile(
              selected: index == selectedIndex,
              selectedTileColor: _panel2,
              title: Text(books[index].name),
              subtitle: Text('${books[index].chapterCount} chapters'),
              onTap: () => onSelected(index),
            ),
          ),
        ),
      );
}
