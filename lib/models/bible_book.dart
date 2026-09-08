import 'bible_chapter.dart';

class BibleBook {
  final int number;
  final String osis;
  final String name;
  final int chapterCount;
  final List<BibleChapter> chapters;

  const BibleBook({
    required this.number,
    required this.osis,
    required this.name,
    required this.chapterCount,
    required this.chapters,
  });
}
