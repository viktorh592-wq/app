/// Embedded poll option (FR-007). A poll must contain at least two options
/// (Data_Validation.md). Plain serializable class (ADR-005).
class PollOption {
  PollOption({this.id = '', this.text = '', this.voteCount = 0});

  /// Local UUID v7 of the option.
  String id;

  String text;

  int voteCount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'voteCount': voteCount,
      };

  static PollOption fromMap(Map<String, dynamic> m) => PollOption(
        id: m['id'] as String? ?? '',
        text: m['text'] as String? ?? '',
        voteCount: (m['voteCount'] as num?)?.toInt() ?? 0,
      );
}
