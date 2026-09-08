import 'bible_verse.dart';

class BibleChapter {
  final int number;
  final String osis;
  final String name;
  final String? title;
  final List<BibleVerse> verses;

  const BibleChapter({
    required this.number,
    required this.osis,
    required this.name,
    required this.title,
    required this.verses,
  });
}
