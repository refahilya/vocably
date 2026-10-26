/// Student-facing instrument text, copied **verbatim** from the researcher's
/// instrument document `Rancangan_Instrumen_Pretest_Vocably.pdf`, §5
/// "Petunjuk untuk siswa" (the boxed instructions, the example item and its
/// explanation), which §4.2 step 3 says students read before the 20 items.
/// Do not paraphrase, shorten or translate; change only if the PDF changes.
library;

const String kResearchInstructionsTitle = 'Petunjuk';

const String kResearchInstructionsParagraph1 =
    'Pilih arti bahasa Indonesia yang paling tepat untuk setiap kata bahasa '
    'Inggris di bawah ini. Hanya ada satu jawaban yang paling tepat.';

const String kResearchInstructionsParagraph2 =
    'Jika kamu tidak tahu artinya, pilih “Saya tidak tahu kata ini”. Jangan '
    'menebak. Tes ini bukan untuk nilai sekolah.';

const String kResearchExampleHeading =
    'Contoh butir (kata ini bukan bagian dari tes):';

const String kResearchExampleWord = 'book';
const String kResearchExamplePosLabel = 'kata benda';

/// a)–e), in the PDF's order; e) is "Saya tidak tahu kata ini".
const List<String> kResearchExampleOptions = [
  'Buku',
  'Pensil',
  'Meja',
  'Tas',
  'Saya tidak tahu kata ini',
];

const String kResearchExampleExplanation =
    'Jawaban yang tepat adalah a) Buku. Bila siswa tidak mengetahui arti '
    '“book”, siswa memilih e).';

/// Display labels for positions 1–5 (a)–e)), matching the example. Only
/// labels: what is stored is the option ID, its text and its position.
const List<String> kResearchOptionLetters = ['a', 'b', 'c', 'd', 'e'];
