class sl_record_details {
  final String question;
  final String selectedanswer;
  final String correctanswer;

  sl_record_details({
    required this.question,
    required this.selectedanswer,
    required this.correctanswer,
  });

  factory sl_record_details.fromMap(Map<String, dynamic> map) {
    return sl_record_details(
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
}
