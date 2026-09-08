import 'package:flutter/material.dart';

import 'models/bible_book.dart';
import 'models/bible_chapter.dart';
import 'models/bible_verse.dart';
import 'services/bible_xml_service.dart';

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
          scaffoldBackgroundColor: const Color(0xFF242424),
          colorScheme: const ColorScheme.dark(primary: Color(0xFFFFCC00)),
          fontFamily: 'Times New Roman',
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

  int selectedVerse = 1;
  int studyTab = 0;
  bool books = true;
  bool study = true;
  bool search = false;

  int selectedBookIndex = 0;
  int selectedChapterIndex = 0;

  @override
  void initState() {
    super.initState();
    _bibleFuture = _bibleService.loadBible();
  }

  BibleBook? _selectedBook(List<BibleBook> bible) {
    if (bible.isEmpty) return null;
    selectedBookIndex = selectedBookIndex.clamp(0, bible.length - 1);
    return bible[selectedBookIndex];
  }

  BibleChapter? _selectedChapter(BibleBook book) {
    if (book.chapters.isEmpty) return null;
    selectedChapterIndex = selectedChapterIndex.clamp(0, book.chapters.length - 1);
    return book.chapters[selectedChapterIndex];
  }

  void _selectBook(int index) {
    setState(() {
      selectedBookIndex = index;
      selectedChapterIndex = 0;
      selectedVerse = 1;
    });
  }

  void _goChapter(List<BibleBook> bible, int direction) {
    if (bible.isEmpty) return;

    var bookIndex = selectedBookIndex;
    var chapterIndex = selectedChapterIndex + direction;

    while (chapterIndex < 0 && bookIndex > 0) {
      bookIndex--;
      chapterIndex = bible[bookIndex].chapters.length - 1;
    }

    while (bookIndex < bible.length &&
        chapterIndex >= bible[bookIndex].chapters.length) {
      chapterIndex -= bible[bookIndex].chapters.length;
      bookIndex++;
    }

    if (bookIndex < 0 || bookIndex >= bible.length) return;
    if (bible[bookIndex].chapters.isEmpty) return;

    setState(() {
      selectedBookIndex = bookIndex;
      selectedChapterIndex = chapterIndex;
      selectedVerse = 1;
    });
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
              final book = _selectedBook(bible);
              final chapter = book == null ? null : _selectedChapter(book);

              if (book == null || chapter == null) {
                return const _ErrorScreen(message: 'Walang laman ang Bible data.');
              }

              if (chapter.verses.isNotEmpty &&
                  !chapter.verses.any((v) => v.number == selectedVerse)) {
                selectedVerse = chapter.verses.first.number;
              }

              final mobile = MediaQuery.sizeOf(context).width < 720;
              final compact = MediaQuery.sizeOf(context).width < 1050;

              return Column(
                children: [
                  _TopBar(
                    onBooks: () => setState(() => books = !books),
                    onStudy: () => setState(() => study = !study),
                    onSearch: () => setState(() => search = !search),
                  ),
                  if (search) const _SearchBar(),
                  Expanded(
                    child: Row(
                      children: [
                        if (books && !mobile)
                          SizedBox(
                            width: compact ? 235 : 285,
                            child: _BookPanel(
                              books: bible,
                              selectedIndex: selectedBookIndex,
                              onSelected: _selectBook,
                            ),
                          ),
                        Expanded(
                          child: _Reader(
                            book: book,
                            chapter: chapter,
                            selectedVerse: selectedVerse,
                            onSelected: (verse) =>
                                setState(() => selectedVerse = verse),
                            onPreviousChapter: () => _goChapter(bible, -1),
                            onNextChapter: () => _goChapter(bible, 1),
                          ),
                        ),
                        if (study && !mobile)
                          SizedBox(
                            width: compact ? 320 : 410,
                            child: _StudyPanel(
                              book: book,
                              chapter: chapter,
                              verse: selectedVerse,
                              tab: studyTab,
                              onTab: (v) => setState(() => studyTab = v),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (mobile)
                    _MobileBar(
                      onBooks: () => setState(() => books = !books),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading Ang Biblia, 2001...'),
          ],
        ),
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
              const Icon(Icons.error_outline, color: Color(0xFFFFCC00), size: 42),
              const SizedBox(height: 16),
              Text(
                message ?? 'Hindi ma-load ang Bible XML.',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                SelectableText(
                  '$error',
                  style: const TextStyle(color: Color(0xFFBDBDBD)),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBooks, onStudy, onSearch;

  const _TopBar({
    required this.onBooks,
    required this.onStudy,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 62,
        color: const Color(0xFF161616),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: Color(0xFFFFCC00)),
            const SizedBox(width: 12),
            const Text(
              'TAGALOG STUDY BIBLE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.3,
                fontSize: 17,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onBooks,
              icon: const Icon(Icons.library_books_outlined),
            ),
            IconButton(
              onPressed: onSearch,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              onPressed: onStudy,
              icon: const Icon(Icons.menu_open_rounded),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF3B3B3C)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ABTAG2001',
                style: TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
              ),
            ),
          ],
        ),
      );
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF1E1E1E),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
        child: const TextField(
          decoration: InputDecoration(
            hintText: 'Search the Bible...',
            prefixIcon: Icon(Icons.search),
            filled: true,
            fillColor: Color(0xFF161616),
          ),
        ),
      );
}

class _BookPanel extends StatelessWidget {
  final List<BibleBook> books;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _BookPanel({
    required this.books,
    required this.selectedIndex,
    required this.onSelected,
  });

  Widget title(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 12, 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFFFCC00),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget item(BibleBook book, int index) {
    final active = index == selectedIndex;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF3B3B3C) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        onTap: () => onSelected(index),
        title: Text(
          book.name,
          style: TextStyle(
            fontSize: 14,
            color: active ? Colors.white : const Color(0xFFBDBDBD),
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: active
            ? const Icon(Icons.chevron_right, size: 17, color: Color(0xFFFFCC00))
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final oldTestament = books.where((book) => book.number <= 39).toList();
    final newTestament = books.where((book) => book.number > 39).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF191718),
        border: Border(right: BorderSide(color: Color(0xFF3B3B3C))),
      ),
      child: ListView(
        children: [
          title('OLD TESTAMENT'),
          ...oldTestament.map((book) => item(book, books.indexOf(book))),
          title('NEW TESTAMENT'),
          ...newTestament.map((book) => item(book, books.indexOf(book))),
        ],
      ),
    );
  }
}

class _Reader extends StatelessWidget {
  final BibleBook book;
  final BibleChapter chapter;
  final int selectedVerse;
  final ValueChanged<int> onSelected;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;

  const _Reader({
    required this.book,
    required this.chapter,
    required this.selectedVerse,
    required this.onSelected,
    required this.onPreviousChapter,
    required this.onNextChapter,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF242424),
        child: Column(
          children: [
            Container(
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                border: Border(bottom: BorderSide(color: Color(0xFF3B3B3C))),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onPreviousChapter,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous chapter',
                  ),
                  const Spacer(),
                  Text(
                    '${book.name.toUpperCase()} ${chapter.number}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onNextChapter,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next chapter',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 28),
                children: [
                  Text(
                    '${book.name} ${chapter.number}',
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Ang Biblia, 2001',
                    style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 13),
                  ),
                  if (chapter.title != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      chapter.title!,
                      style: const TextStyle(
                        color: Color(0xFFFFCC00),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  ...chapter.verses.map(
                    (verse) => InkWell(
                      onTap: () => onSelected(verse.number),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          color: verse.number == selectedVerse
                              ? const Color(0xFF3B3B3C)
                              : Colors.transparent,
                          border: verse.number == selectedVerse
                              ? const Border(
                                  left: BorderSide(
                                    color: Color(0xFFFFCC00),
                                    width: 3,
                                  ),
                                )
                              : null,
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'Times New Roman',
                              fontSize: 20,
                              height: 1.62,
                              color: Colors.white,
                            ),
                            children: [
                              TextSpan(
                                text: '${verse.number} ',
                                style: const TextStyle(
                                  color: Color(0xFFFFCC00),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              TextSpan(text: verse.text),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _StudyPanel extends StatelessWidget {
  final BibleBook book;
  final BibleChapter chapter;
  final int verse;
  final int tab;
  final ValueChanged<int> onTab;

  const _StudyPanel({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.tab,
    required this.onTab,
  });

  static const tabs = ['Study', 'Exegesis', 'Theology', 'References'];

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          border: Border(left: BorderSide(color: Color(0xFF3B3B3C))),
        ),
        child: Column(
          children: [
            Container(
              color: const Color(0xFF161616),
              padding: const EdgeInsets.fromLTRB(18, 15, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_stories, color: Color(0xFFFFCC00), size: 18),
                      const SizedBox(width: 9),
                      Text(
                        '${book.name.toUpperCase()} ${chapter.number}:$verse',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: .8,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: tabs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 4),
                      itemBuilder: (_, i) => InkWell(
                        onTap: () => onTab(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == tab
                                ? const Color(0xFF3B3B3C)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: i == tab
                                    ? const Color(0xFFFFCC00)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            tabs[i],
                            style: TextStyle(
                              fontSize: 11,
                              color: i == tab
                                  ? Colors.white
                                  : const Color(0xFFBDBDBD),
                              fontWeight: i == tab
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: _body(tab),
              ),
            ),
          ],
        ),
      );

  List<Widget> _body(int i) => [
        if (i == 0) ...[
          const _Section(
            'EXPOSITION',
            Icons.menu_book_outlined,
            'Ang talata ay ipaliliwanag dito sa malinaw at natural na Tagalog, na nakatuon sa kahulugan nito sa konteksto.',
          ),
          const SizedBox(height: 18),
          const _Section(
            'CONTEXT',
            Icons.history_edu_outlined,
            'Ang literary, historical, at immediate context ng passage ay lalabas dito.',
          ),
          const SizedBox(height: 18),
          const _Section(
            'APPLICATION',
            Icons.lightbulb_outline,
            'Mga makabuluhang implikasyon at aplikasyon na nakaugat sa teksto.',
          ),
        ] else if (i == 1) ...[
          const _Section(
            'TEXT & GRAMMAR',
            Icons.translate,
            'Greek o Hebrew observations, grammar, syntax, lexical details, at mahahalagang textual observations.',
          ),
          const SizedBox(height: 18),
          const _Section(
            'EXEGETICAL SYNTHESIS',
            Icons.account_tree_outlined,
            'Orhinal na Tagalog synthesis ng exegetical research.',
          ),
        ] else if (i == 2) ...[
          const _Section(
            'BIBLICAL THEOLOGY',
            Icons.auto_awesome_outlined,
            'Paano nauugnay ang passage sa mas malawak na biblical-theological storyline.',
          ),
          const SizedBox(height: 18),
          const _Section(
            'SYSTEMATIC THEOLOGY',
            Icons.schema_outlined,
            'Mga doktrinal na implikasyon na may malinaw na kaugnayan sa teksto.',
          ),
        ] else ...[
          const _Section(
            'CROSS REFERENCES',
            Icons.link,
            'Mga kaugnay na talata at themes.',
          ),
          const SizedBox(height: 18),
          const _Section(
            'SOURCES',
            Icons.library_books_outlined,
            'Source mapping at editorial references para sa research corpus.',
          ),
        ],
      ];
}

class _Section extends StatelessWidget {
  final String title, text;
  final IconData icon;

  const _Section(this.title, this.icon, this.text);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFFFFCC00)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Color(0xFFFFCC00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFBDBDBD),
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      );
}

class _MobileBar extends StatelessWidget {
  final VoidCallback onBooks, onStudy;

  const _MobileBar({required this.onBooks, required this.onStudy});

  @override
  Widget build(BuildContext context) => Container(
        height: 58,
        color: const Color(0xFF161616),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: onBooks,
                icon: const Icon(Icons.library_books_outlined),
                label: const Text('Books'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: onStudy,
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('Study'),
              ),
            ),
          ],
        ),
      );
}
