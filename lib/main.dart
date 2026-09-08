import 'package:flutter/material.dart';

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
  @override State<BibleShell> createState() => BibleShellState();
}

class BibleShellState extends State<BibleShell> {
  int selectedVerse = 1;
  int studyTab = 0;
  bool books = true;
  bool study = true;
  bool search = false;

  final verses = const [
    (1, 'Nang pasimula, nilikha ng Diyos ang langit at ang lupa.'),
    (2, 'Ang lupa ay walang anyo at walang laman, at binalot sa kadiliman ang kalaliman; at ang Espiritu ng Diyos ay kumikilos sa ibabaw ng mga tubig.'),
    (3, 'At sinabi ng Diyos, “Magkaroon ng liwanag,” at nagkaroon ng liwanag.'),
    (4, 'At nakita ng Diyos ang liwanag, na ito ay mabuti; at pinaghiwalay ng Diyos ang liwanag sa kadiliman.'),
    (5, 'Tinawag ng Diyos ang liwanag na Araw, at ang kadiliman ay tinawag niyang Gabi. At nagkaroon ng gabi at nagkaroon ng umaga, ang unang araw.'),
    (6, 'At sinabi ng Diyos, “Magkaroon ng kalawakan sa gitna ng mga tubig, at paghiwalayin nito ang tubig sa tubig.”'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: LayoutBuilder(builder: (_, c) {
      final mobile = c.maxWidth < 720;
      final compact = c.maxWidth < 1050;
      return Column(children: [
        _TopBar(
          onBooks: () => setState(() => books = !books),
          onStudy: () => setState(() => study = !study),
          onSearch: () => setState(() => search = !search),
        ),
        if (search) const _SearchBar(),
        Expanded(child: Row(children: [
          if (books && !mobile)
            SizedBox(width: compact ? 235 : 285, child: const _BookPanel()),
          Expanded(child: _Reader(
            verses: verses, selectedVerse: selectedVerse,
            onSelected: (v) => setState(() => selectedVerse = v),
          )),
          if (study && !mobile)
            SizedBox(width: compact ? 320 : 410,
              child: _StudyPanel(
                verse: selectedVerse, tab: studyTab,
                onTab: (v) => setState(() => studyTab = v),
              )),
        ])),
        if (mobile) _MobileBar(
          onBooks: () => setState(() => books = !books),
          onStudy: () => setState(() => study = !study),
        ),
      ]);
    })),
  );
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBooks, onStudy, onSearch;
  const _TopBar({required this.onBooks, required this.onStudy, required this.onSearch});
  @override
  Widget build(BuildContext context) => Container(
    height: 62, color: const Color(0xFF161616),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Row(children: [
      const Icon(Icons.menu_book_rounded, color: Color(0xFFFFCC00)),
      const SizedBox(width: 12),
      const Text('TAGALOG STUDY BIBLE',
        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.3, fontSize: 17)),
      const Spacer(),
      IconButton(onPressed: onBooks, icon: const Icon(Icons.library_books_outlined)),
      IconButton(onPressed: onSearch, icon: const Icon(Icons.search)),
      IconButton(onPressed: onStudy, icon: const Icon(Icons.menu_open_rounded)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF3B3B3C)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('ABTAG2001', style: TextStyle(fontSize: 12, color: Color(0xFFBDBDBD))),
      ),
    ]),
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
        filled: true, fillColor: Color(0xFF161616),
      ),
    ),
  );
}

class _BookPanel extends StatelessWidget {
  const _BookPanel();
  static const ot = ['Genesis','Exodus','Leviticus','Numbers','Deuteronomy','Joshua','Judges','Ruth','1 Samuel','2 Samuel','1 Kings','2 Kings','1 Chronicles','2 Chronicles','Ezra','Nehemiah','Esther','Job','Psalms','Proverbs','Ecclesiastes','Song of Solomon','Isaiah','Jeremiah','Lamentations','Ezekiel','Daniel'];
  static const nt = ['Matthew','Mark','Luke','John','Acts','Romans','1 Corinthians','2 Corinthians','Galatians','Ephesians','Philippians','Colossians','1 Thessalonians','2 Thessalonians','1 Timothy','2 Timothy','Titus','Philemon','Hebrews','James','1 Peter','2 Peter','1 John','2 John','3 John','Jude','Revelation'];

  Widget title(String s) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 12, 8),
    child: Text(s, style: const TextStyle(color: Color(0xFFFFCC00), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
  );

  Widget item(String s, bool active) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(color: active ? const Color(0xFF3B3B3C) : Colors.transparent, borderRadius: BorderRadius.circular(4)),
    child: ListTile(dense: true, visualDensity: VisualDensity.compact,
      title: Text(s, style: TextStyle(fontSize: 14, color: active ? Colors.white : const Color(0xFFBDBDBD), fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      trailing: active ? const Icon(Icons.chevron_right, size: 17, color: Color(0xFFFFCC00)) : null),
  );

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF191718),
      border: Border(right: BorderSide(color: Color(0xFF3B3B3C))),
    ),
    child: ListView(children: [title('OLD TESTAMENT'), ...ot.map((b) => item(b, b == 'Genesis')), title('NEW TESTAMENT'), ...nt.map((b) => item(b, false))]),
  );
}

class _Reader extends StatelessWidget {
  final List<(int,String)> verses;
  final int selectedVerse;
  final ValueChanged<int> onSelected;
  const _Reader({required this.verses, required this.selectedVerse, required this.onSelected});

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF242424),
    child: Column(children: [
      Container(height: 52,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          border: Border(bottom: BorderSide(color: Color(0xFF3B3B3C))),
        ),
        child: Row(children: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_left)),
          const Spacer(), const Text('GENESIS 1', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          const Spacer(), IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right)),
        ])),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 28), children: [
        const Text('Genesis 1', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        const Text('Ang Biblia, 2001', style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 13)),
        const SizedBox(height: 26),
        ...verses.map((v) => InkWell(
          onTap: () => onSelected(v.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: v.$1 == selectedVerse ? const Color(0xFF3B3B3C) : Colors.transparent,
              border: v.$1 == selectedVerse ? const Border(left: BorderSide(color: Color(0xFFFFCC00), width: 3)) : null,
            ),
            child: RichText(text: TextSpan(
              style: const TextStyle(fontFamily: 'Times New Roman', fontSize: 20, height: 1.62, color: Colors.white),
              children: [
                TextSpan(text: '${v.$1} ', style: const TextStyle(color: Color(0xFFFFCC00), fontWeight: FontWeight.bold, fontSize: 13)),
                TextSpan(text: v.$2),
              ],
            )),
          ),
        )),
      ])),
    ]),
  );
}

class _StudyPanel extends StatelessWidget {
  final int verse, tab;
  final ValueChanged<int> onTab;
  const _StudyPanel({required this.verse, required this.tab, required this.onTab});

  static const tabs = ['Study','Exegesis','Theology','References'];

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF1E1E1E),
      border: Border(left: BorderSide(color: Color(0xFF3B3B3C))),
    ),
    child: Column(children: [
      Container(color: const Color(0xFF161616), padding: const EdgeInsets.fromLTRB(18, 15, 10, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_stories, color: Color(0xFFFFCC00), size: 18),
            const SizedBox(width: 9),
            Text('GENESIS 1:$verse', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: .8, fontSize: 13)),
          ]),
          const SizedBox(height: 13),
          SizedBox(height: 34, child: ListView.separated(
            scrollDirection: Axis.horizontal, itemCount: tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (_, i) => InkWell(
              onTap: () => onTab(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == tab ? const Color(0xFF3B3B3C) : Colors.transparent,
                  border: Border(bottom: BorderSide(color: i == tab ? const Color(0xFFFFCC00) : Colors.transparent, width: 2)),
                ),
                child: Text(tabs[i], style: TextStyle(fontSize: 11, color: i == tab ? Colors.white : const Color(0xFFBDBDBD), fontWeight: i == tab ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          )),
        ])),
      Expanded(child: ListView(padding: const EdgeInsets.all(18), children: _body(tab))),
    ]),
  );

  List<Widget> _body(int i) => [
    if (i == 0) ...[
      const _Section('EXPOSITION', Icons.menu_book_outlined, 'Ang talata ay ipaliliwanag dito sa malinaw at natural na Tagalog, na nakatuon sa kahulugan nito sa konteksto.'),
      const SizedBox(height: 18),
      const _Section('CONTEXT', Icons.history_edu_outlined, 'Ang literary, historical, at immediate context ng passage ay lalabas dito.'),
      const SizedBox(height: 18),
      const _Section('APPLICATION', Icons.lightbulb_outline, 'Mga makabuluhang implikasyon at aplikasyon na nakaugat sa teksto.'),
    ] else if (i == 1) ...[
      const _Section('TEXT & GRAMMAR', Icons.translate, 'Greek o Hebrew observations, grammar, syntax, lexical details, at mahahalagang textual observations.'),
      const SizedBox(height: 18),
      const _Section('EXEGETICAL SYNTHESIS', Icons.account_tree_outlined, 'Orhinal na Tagalog synthesis ng exegetical research.'),
    ] else if (i == 2) ...[
      const _Section('BIBLICAL THEOLOGY', Icons.auto_awesome_outlined, 'Paano nauugnay ang passage sa mas malawak na biblical-theological storyline.'),
      const SizedBox(height: 18),
      const _Section('SYSTEMATIC THEOLOGY', Icons.schema_outlined, 'Mga doktrinal na implikasyon na may malinaw na kaugnayan sa teksto.'),
    ] else ...[
      const _Section('CROSS REFERENCES', Icons.link, 'Mga kaugnay na talata at themes.'),
      const SizedBox(height: 18),
      const _Section('SOURCES', Icons.library_books_outlined, 'Source mapping at editorial references para sa research corpus.'),
    ],
  ];
}

class _Section extends StatelessWidget {
  final String title, text;
  final IconData icon;
  const _Section(this.title, this.icon, this.text);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(icon, size: 16, color: const Color(0xFFFFCC00)), const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFFFFCC00)))]),
    const SizedBox(height: 9),
    Text(text, style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14, height: 1.55)),
  ]);
}

class _MobileBar extends StatelessWidget {
  final VoidCallback onBooks, onStudy;
  const _MobileBar({required this.onBooks, required this.onStudy});
  @override
  Widget build(BuildContext context) => Container(height: 58, color: const Color(0xFF161616),
    child: Row(children: [
      Expanded(child: TextButton.icon(onPressed: onBooks, icon: const Icon(Icons.library_books_outlined), label: const Text('Books'))),
      Expanded(child: TextButton.icon(onPressed: onStudy, icon: const Icon(Icons.auto_stories_outlined), label: const Text('Study'))),
    ]));
}