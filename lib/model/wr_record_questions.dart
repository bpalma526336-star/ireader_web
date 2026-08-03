class wr_record_details {
  final String question;
  final String selectedanswer;
  final String correctanswer;

  wr_record_details({
    required this.question,
    required this.selectedanswer,
    required this.correctanswer,
  });

  factory wr_record_details.fromMap(Map<String, dynamic> map) {
    return wr_record_details(
      question: map['question'] ?? "",
      selectedanswer: map['selectedanswer'] ?? "",
      correctanswer: map['correctanswer'] ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'selectedanswer': selectedanswer,
      'correctanswer': correctanswer,
    };
  }

  wr_record_details copyWith({
    String? question,
    String? selectedanswer,
    String? correctanswer,
  }) {
    return wr_record_details(
      question: question ?? this.question,
      selectedanswer: selectedanswer ?? this.selectedanswer,
      correctanswer: correctanswer ?? this.correctanswer,
    );
  }
}
