import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'models/bible_book.dart';
import 'models/bible_chapter.dart';
import 'models/bible_verse.dart';
import 'services/bible_xml_service.dart';
import 'services/study_bible_service.dart';

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
  final StudyBibleService _studyService = StudyBibleService();
  late Future<List<BibleBook>> _bibleFuture;
  late Future<StudyBibleData> _studyFuture;

  int selectedBookIndex = 0;
  int selectedChapterIndex = 0;
  int? selectedVerse;
  String selectedTranslation = 'ABTAG';

  bool books = true;
  bool study = true;

  // Translation cache. ABTAG is supplied by _bibleFuture.
  final Map<String, List<BibleBook>> _translationCache = {};
  final Map<String, Future<List<BibleBook>>> _translationLoads = {};

  @override
  void initState() {
    super.initState();
    _bibleFuture = _bibleService.loadBible();
    _studyFuture = _studyService.load();

    // Preload the complete English translations in the background.
    for (final id in const ['ESV', 'NKJV', 'NASB', 'LSB', 'NIV']) {
      _loadTranslation(id);
    }
  }

  Future<List<BibleBook>> _loadTranslation(String id) {
    final cached = _translationCache[id];
    if (cached != null) return Future.value(cached);

    final existing = _translationLoads[id];
    if (existing != null) return existing;

    // Chain the future directly so awaiters wait for the cache
    final future = _bibleService.loadTranslation(id).then((data) {
      if (!mounted) return data;
      _translationLoads.remove(id);

      if (data.isNotEmpty) {
        _translationCache[id] = data;
      }

      if (selectedTranslation == id) {
        setState(() {});
      }
      return data;
    }).catchError((_) {
      _translationLoads.remove(id);
      if (mounted && selectedTranslation == id) {
        setState(() {});
      }
      return <BibleBook>[];
    });

    _translationLoads[id] = future;
    return future;
  }

  Future<void> _changeTranslation(String id) async {
    if (id == selectedTranslation) return;

    setState(() {
      selectedTranslation = id;
      selectedVerse = null;
    });

    if (id == 'ABTAG') return;

    await _loadTranslation(id);

    if (!mounted || selectedTranslation != id) return;
    setState(() {});
  }

  BibleBook? _bookAt(List<BibleBook> bible, int index) =>
      index >= 0 && index < bible.length ? bible[index] : null;

  BibleChapter? _chapterAt(BibleBook book, int index) =>
      index >= 0 && index < book.chapters.length ? book.chapters[index] : null;

  /// Gets the same book/chapter from the selected translation.
  /// While an English XML is still loading, ABTAG remains visible rather than
  /// showing stale/empty data.
  BibleBook _getTranslatedBook(BibleBook abtagBook) {
    if (selectedTranslation == 'ABTAG') return abtagBook;

    final translationBooks = _translationCache[selectedTranslation];
    if (translationBooks == null || translationBooks.isEmpty) {
      return abtagBook;
    }

    if (selectedBookIndex >= 0 && selectedBookIndex < translationBooks.length) {
      return translationBooks[selectedBookIndex];
    }

    return abtagBook;
  }

  BibleChapter _getTranslatedChapter(
      BibleBook translatedBook, BibleChapter abtagChapter) {
    if (selectedTranslation == 'ABTAG') return abtagChapter;

    if (selectedChapterIndex >= 0 &&
        selectedChapterIndex < translatedBook.chapters.length) {
      final matchChapter = translatedBook.chapters[selectedChapterIndex];
      if (matchChapter.verses.isNotEmpty) {
        return matchChapter;
      }
    }

    return abtagChapter;
  }

  String get _translationLabel =>
      BibleXmlService.translationNames[selectedTranslation] ??
      selectedTranslation;

  void _selectBook(int index) => setState(() {
        selectedBookIndex = index;
        selectedChapterIndex = 0;
        selectedVerse = null;
      });

  void _selectChapter(int index) => setState(() {
        selectedChapterIndex = index;
        selectedVerse = null;
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
    if (chapterIndex < 0 || chapterIndex >= bible[bookIndex].chapters.length)
      return;

    setState(() {
      selectedBookIndex = bookIndex;
      selectedChapterIndex = chapterIndex;
      selectedVerse = null;
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
                    _studyFuture = _studyService.load();
                  }),
                );
              }

              final bible = snapshot.data ?? const <BibleBook>[];
              final book = _bookAt(bible, selectedBookIndex);
              if (book == null) {
                return const _ErrorScreen(
                    message: 'Walang laman ang Bible data.');
              }
              final chapter = _chapterAt(book, selectedChapterIndex);
              if (chapter == null) {
                return const _ErrorScreen(
                  message: 'Walang chapter data para sa napiling aklat.',
                );
              }
              final width = MediaQuery.sizeOf(context).width;
              final mobile = width < 900;
              final narrowDesktop = width < 1250;
              final translatedBook = _getTranslatedBook(book);
              final translatedChapter =
                  _getTranslatedChapter(translatedBook, chapter);

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
                            chapter: _getTranslatedChapter(book, chapter),
                            selectedVerse: selectedVerse,
                            translationLabel: _translationLabel,
                            selectedTranslation: selectedTranslation,
                            onTranslationChanged: _changeTranslation,
                            onSelected: (verse) =>
                                setState(() => selectedVerse = verse),
                            onClearSelection: () =>
                                setState(() => selectedVerse = null),
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
                            child: FutureBuilder<StudyBibleData>(
                              future: _studyFuture,
                              builder: (context, studySnapshot) {
                                if (studySnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const _StudyLoadingPanel();
                                }
                                if (studySnapshot.hasError) {
                                  return _StudyErrorPanel(
                                      error: studySnapshot.error);
                                }
                                final data = studySnapshot.data;
                                if (data == null) {
                                  return const _StudyErrorPanel();
                                }
                                return _StudyPanel(
                                  book: book,
                                  chapter: chapter,
                                  verse: selectedVerse,
                                  data: data,
                                );
                              },
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
              Text(message ?? 'Hindi ma-load ang Bible XML.',
                  textAlign: TextAlign.center),
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
                      const Text('OLD TESTAMENT',
                          style: TextStyle(
                              color: _gold,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
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
                      const Text('NEW TESTAMENT',
                          style: TextStyle(
                              color: _gold,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
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
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groups.entries.map((entry) {
          final items = entry.value
              .map((n) => byNumber[n])
              .whereType<BibleBook>()
              .toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 11),
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
                const SizedBox(height: 2),
                ...items.map((book) {
                  final index = books.indexOf(book);
                  final active = index == selectedIndex;
                  return InkWell(
                    onTap: () => onSelected(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        book.name,
                        style: TextStyle(
                          color: active ? _gold : _text,
                          fontSize: 13.5,
                          fontWeight:
                              active ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }).toList(),
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
            Text('BOOK INTRODUCTIONS',
                style: TextStyle(
                    color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('THEOLOGY',
                style: TextStyle(
                    color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('DOCTRINES',
                style: TextStyle(
                    color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 22),
            Row(
              children: [
                Text('Login',
                    style: TextStyle(
                        color: _text,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                SizedBox(width: 28),
                Text('A+',
                    style: TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                SizedBox(width: 12),
                Text('A-',
                    style: TextStyle(
                        color: _muted,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      );
}

class _Reader extends StatefulWidget {
  final BibleBook book;
  final BibleChapter chapter;
  final int? selectedVerse;
  final ValueChanged<int> onSelected;
  final VoidCallback onClearSelection;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onChapterPicker;
  final VoidCallback onBooks;
  final VoidCallback onStudy;
  final bool showBooksButton;
  final String translationLabel;
  final String selectedTranslation;
  final ValueChanged<String> onTranslationChanged;

  const _Reader({
    required this.book,
    required this.chapter,
    required this.selectedVerse,
    required this.onSelected,
    required this.onClearSelection,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onChapterPicker,
    required this.onBooks,
    required this.onStudy,
    required this.showBooksButton,
    required this.translationLabel,
    required this.selectedTranslation,
    required this.onTranslationChanged,
  });

  @override
  State<_Reader> createState() => _ReaderState();
}

class _ReaderState extends State<_Reader> {
  final ScrollController _scrollController = ScrollController();

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
              selectedTranslation: widget.selectedTranslation,
              onTranslationChanged: widget.onTranslationChanged,
            ),
            Container(
              height: 55,
              decoration: const BoxDecoration(
                color: _panel2,
                border: Border(bottom: BorderSide(color: _line)),
              ),
              child: Row(
                children: [
                  IconButton(
                      onPressed: widget.onPreviousChapter,
                      icon: const Icon(Icons.chevron_left, size: 30)),
                  Expanded(
                    child: Center(
                      child: InkWell(
                        onTap: widget.onChapterPicker,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Text(
                            '${widget.book.name} ${widget.chapter.number}',
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                      onPressed: widget.onNextChapter,
                      icon: const Icon(Icons.chevron_right, size: 30)),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                trackVisibility: true,
                thickness: 10,
                radius: const Radius.circular(8),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.onClearSelection,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(60, 32, 60, 70),
                    children: [
                      Text(
                        '${widget.book.name} ${widget.chapter.number}',
                        style: const TextStyle(
                            fontSize: 29, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.translationLabel,
                          style: const TextStyle(color: _muted, fontSize: 13)),
                      if (widget.chapter.title != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          widget.chapter.title!,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _BibleParagraphs(
                        verses: widget.chapter.verses,
                        selectedVerse: widget.selectedVerse,
                        onSelected: widget.onSelected,
                      ),
                    ],
                  ),
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
  final String selectedTranslation;
  final ValueChanged<String> onTranslationChanged;
  const _ReaderToolbar({
    required this.onBooks,
    required this.onStudy,
    required this.showBooksButton,
    required this.selectedTranslation,
    required this.onTranslationChanged,
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
            const Spacer(),
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
            _TranslationButton(
              'ABTAG',
              active: selectedTranslation == 'ABTAG',
              onTap: () => onTranslationChanged('ABTAG'),
            ),
            const SizedBox(width: 8),
            _TranslationButton(
              'ESV',
              active: selectedTranslation == 'ESV',
              onTap: () => onTranslationChanged('ESV'),
            ),
            const SizedBox(width: 8),
            _TranslationButton(
              'NKJV',
              active: selectedTranslation == 'NKJV',
              onTap: () => onTranslationChanged('NKJV'),
            ),
            _TranslationButton(
              'NASB',
              active: selectedTranslation == 'NASB',
              onTap: () => onTranslationChanged('NASB'),
            ),
            const SizedBox(width: 8),
            _TranslationButton(
              'LSB',
              active: selectedTranslation == 'LSB',
              onTap: () => onTranslationChanged('LSB'),
            ),
            const SizedBox(width: 8),
            _TranslationButton(
              'NIV',
              active: selectedTranslation == 'NIV',
              onTap: () => onTranslationChanged('NIV'),
            ),
            const Spacer(),
            IconButton(
                onPressed: onStudy,
                icon: const Icon(Icons.view_sidebar_outlined),
                tooltip: 'Study panel'),
          ],
        ),
      );
}

class _TranslationButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TranslationButton(
    this.label, {
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF121212) : const Color(0xFF181818),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}

class _BibleParagraphs extends StatelessWidget {
  final List<BibleVerse> verses;
  final int? selectedVerse;
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
  final int? selectedVerse;
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
        .map((verse) => TapGestureRecognizer()
          ..onTap = () => widget.onSelected(verse.number))
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
            color: selected ? const Color(0xFF202020) : _gold,
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
            color: selected ? const Color(0xFF202020) : _text,
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

class _StudyLoadingPanel extends StatelessWidget {
  const _StudyLoadingPanel();
  @override
  Widget build(BuildContext context) => Container(
        color: _panel,
        child: const Center(child: CircularProgressIndicator(color: _gold)),
      );
}

class _StudyErrorPanel extends StatelessWidget {
  final Object? error;
  const _StudyErrorPanel({this.error});
  @override
  Widget build(BuildContext context) => Container(
        color: _panel,
        padding: const EdgeInsets.all(18),
        child: Text(
          error == null
              ? 'Study data is unavailable.'
              : 'Study data error:\n$error',
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
      );
}

class _StudyPanel extends StatefulWidget {
  final BibleBook book;
  final BibleChapter chapter;
  final int? verse;
  final StudyBibleData data;

  const _StudyPanel({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.data,
  });

  @override
  State<_StudyPanel> createState() => _StudyPanelState();
}

class _StudyPanelState extends State<_StudyPanel> {
  final ScrollController _notesScrollController = ScrollController();

  @override
  void dispose() {
    _notesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.verse == null
        ? null
        : widget.chapter.verses
            .where((v) => v.number == widget.verse)
            .firstOrNull;
    final notes = widget.verse == null
        ? const <StudyNote>[]
        : widget.data
            .notesFor(widget.book.number, widget.chapter.number, widget.verse!);
    final refs = widget.verse == null
        ? const <CrossReference>[]
        : widget.data.referencesFor(
            widget.book.number, widget.chapter.number, widget.verse!);
    final exegetical = widget.verse == null
        ? null
        : widget.data.exegeticalFor(
            widget.book.number, widget.chapter.number, widget.verse!);

    return Container(
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(left: BorderSide(color: _line)),
      ),
      child: Scrollbar(
        controller: _notesScrollController,
        thumbVisibility: true,
        interactive: true,
        trackVisibility: true,
        thickness: 10,
        radius: const Radius.circular(8),
        child: SingleChildScrollView(
          controller: _notesScrollController,
          primary: false,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 45),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notes and Cross References',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                widget.verse == null
                    ? 'No verse selected'
                    : 'Selected ${widget.book.name} ${widget.chapter.number}:${widget.verse}',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
              const SizedBox(height: 16),
              if (selected == null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 120, horizontal: 18),
                  child: Center(
                    child: Text(
                      'Select a verse to view notes and cross references.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: _muted, fontSize: 13, height: 1.5),
                    ),
                  ),
                ),
              ] else ...[
                const Text('SCRIPTURE',
                    style: TextStyle(
                        color: _gold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 7),
                Text(
                  selected.text,
                  style:
                      const TextStyle(color: _text, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 20),
              ],
              _StudySection(
                title: 'Cross References',
                child: refs.isEmpty
                    ? const Text(
                        'No cross references are listed for this verse.',
                        style: TextStyle(
                            color: _muted, fontSize: 12, height: 1.45),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: refs
                            .map((ref) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${ref.verse}  ',
                                          style: const TextStyle(
                                              color: _gold,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                        TextSpan(
                                          text: ref.text,
                                          style: const TextStyle(
                                              color: _text,
                                              fontSize: 12,
                                              height: 1.45),
                                        ),
                                      ],
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 18),
              _StudySection(
                title: 'Study Notes',
                child: notes.isEmpty
                    ? const Text(
                        'No study note is attached to this verse in the loaded study corpus.',
                        style: TextStyle(
                            color: _muted, fontSize: 12, height: 1.45),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: notes
                            .map((note) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        note.range,
                                        style: const TextStyle(
                                            color: _gold,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      if (note.title.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          note.title,
                                          style: const TextStyle(
                                              color: _text,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              height: 1.35),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        note.text,
                                        style: const TextStyle(
                                            color: _text,
                                            fontSize: 12.5,
                                            height: 1.5),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
              ),
              if (exegetical != null) ...[
                const SizedBox(height: 18),
                _StudySection(
                  title: 'Exegetical Notes',
                  child: _ExegeticalDocumentView(markdown: exegetical.markdown),
                ),
              ],
              const SizedBox(height: 18),
              const _StudySection(
                title: 'Source',
                child: Text(
                  'ESV Study Bible — Study Notes and Cross References',
                  style: TextStyle(color: _muted, fontSize: 11.5, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExegeticalDocumentView extends StatelessWidget {
  final String markdown;
  const _ExegeticalDocumentView({required this.markdown});

  @override
  Widget build(BuildContext context) {
    final blocks = _parseStudyMarkdown(markdown);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks
          .map<Widget>((block) => _StudyMarkdownBlock(block: block))
          .toList(),
    );
  }
}

class _StudyMarkdownData {
  final String text;
  final _StudyBlockKind kind;
  const _StudyMarkdownData(this.text, this.kind);
}

enum _StudyBlockKind {
  title,
  heading,
  subheading,
  paragraph,
  bullet,
  quote,
  divider
}

List<_StudyMarkdownData> _parseStudyMarkdown(String markdown) {
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  final blocks = <_StudyMarkdownData>[];
  final paragraph = <String>[];

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    final text = paragraph.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isNotEmpty)
      blocks.add(_StudyMarkdownData(text, _StudyBlockKind.paragraph));
    paragraph.clear();
  }

  for (var raw in lines) {
    var line = raw.trim();
    if (line.isEmpty) {
      flushParagraph();
      continue;
    }
    if (line == '---') {
      flushParagraph();
      blocks.add(const _StudyMarkdownData('', _StudyBlockKind.divider));
      continue;
    }
    if (line.startsWith('**') && line.endsWith('**')) {
      flushParagraph();
      final clean = _stripMarkdown(line);
      final kind = blocks.isEmpty
          ? _StudyBlockKind.title
          : RegExp(r'^\d+\.\s').hasMatch(clean)
              ? _StudyBlockKind.subheading
              : _StudyBlockKind.heading;
      blocks.add(_StudyMarkdownData(clean, kind));
      continue;
    }
    if (RegExp(r'^\*\*\d+\.').hasMatch(line)) {
      flushParagraph();
      blocks.add(
          _StudyMarkdownData(_stripMarkdown(line), _StudyBlockKind.subheading));
      continue;
    }
    if (line.startsWith('- ')) {
      flushParagraph();
      blocks.add(_StudyMarkdownData(
          _stripMarkdown(line.substring(2)), _StudyBlockKind.bullet));
      continue;
    }
    if (line.startsWith('>')) {
      flushParagraph();
      blocks.add(_StudyMarkdownData(
          _stripMarkdown(line.substring(1).trim()), _StudyBlockKind.quote));
      continue;
    }
    if (line.startsWith('|')) {
      flushParagraph();
      final cells = line
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (cells.isNotEmpty &&
          !cells.every((e) => RegExp(r'^-+$').hasMatch(e))) {
        blocks.add(
            _StudyMarkdownData(cells.join('    '), _StudyBlockKind.paragraph));
      }
      continue;
    }
    paragraph.add(line);
  }
  flushParagraph();
  return blocks;
}

String _stripMarkdown(String text) => text
    .replaceAll(RegExp(r'\*\*'), '')
    .replaceAll(RegExp(r'\*'), '')
    .replaceAll(RegExp(r'`+'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class _StudyMarkdownBlock extends StatelessWidget {
  final _StudyMarkdownData block;
  const _StudyMarkdownBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    switch (block.kind) {
      case _StudyBlockKind.divider:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: _line),
        );
      case _StudyBlockKind.title:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            block.text,
            style: const TextStyle(
                color: _text,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                height: 1.3),
          ),
        );
      case _StudyBlockKind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            block.text,
            style: const TextStyle(
                color: _gold,
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                height: 1.35),
          ),
        );
      case _StudyBlockKind.subheading:
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 5),
          child: Text(
            block.text,
            style: const TextStyle(
                color: _text,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                height: 1.4),
          ),
        );
      case _StudyBlockKind.bullet:
        return Padding(
          padding: const EdgeInsets.only(left: 7, bottom: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(color: _gold, fontSize: 12.5)),
              Expanded(
                  child: Text(block.text,
                      style: const TextStyle(
                          color: _text, fontSize: 12.2, height: 1.5))),
            ],
          ),
        );
      case _StudyBlockKind.quote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.only(left: 10),
          decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: _gold, width: 2))),
          child: Text(block.text,
              style: const TextStyle(
                  color: _muted,
                  fontSize: 12.2,
                  height: 1.5,
                  fontStyle: FontStyle.italic)),
        );
      case _StudyBlockKind.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _RichStudyText(block.text),
        );
    }

    return const SizedBox.shrink();
  }
}

class _RichStudyText extends StatelessWidget {
  final String text;
  const _RichStudyText(this.text);

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)');
    var last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final value = match.group(0)!;
      if (value.startsWith('`')) {
        spans.add(TextSpan(
            text: value.substring(1, value.length - 1),
            style: const TextStyle(color: _gold, fontFamily: 'Georgia')));
      } else {
        spans.add(TextSpan(
            text: value.replaceAll('*', ''),
            style: const TextStyle(fontWeight: FontWeight.bold)));
      }
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(color: _text, fontSize: 12.2, height: 1.55),
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
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
            Expanded(
                child: TextButton.icon(
                    onPressed: onBooks,
                    icon: const Icon(Icons.menu_book),
                    label: const Text('Books'))),
            Expanded(
                child: TextButton.icon(
                    onPressed: onStudy,
                    icon: const Icon(Icons.view_sidebar),
                    label: const Text('Study'))),
          ],
        ),
      );
}

class _ChapterPickerDialog extends StatelessWidget {
  final BibleBook book;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _ChapterPickerDialog(
      {required this.book,
      required this.selectedIndex,
      required this.onSelected});
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
                  style: TextStyle(
                      color: index == selectedIndex ? Colors.black : _text),
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
  const _BookPickerDialog(
      {required this.books,
      required this.selectedIndex,
      required this.onSelected});
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
