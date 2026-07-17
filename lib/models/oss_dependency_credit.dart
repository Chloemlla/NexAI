/// One curated third-party / bundled component credit entry.
class OssDependencyCredit {
  final String name;
  final String author;
  final String description;
  final String license;
  final String? url;

  const OssDependencyCredit({
    required this.name,
    required this.author,
    required this.description,
    required this.license,
    this.url,
  });
}
