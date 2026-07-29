class compleveldetails {
  final String question;
  final String selectedanswer;
  final String correctanswer;

  compleveldetails({
    required this.question,
    required this.selectedanswer,
    required this.correctanswer,
  });

  factory compleveldetails.fromMap(Map<String, dynamic> map) {
    return compleveldetails(
      question: map['totalquestions'] ?? "",
      selectedanswer: map['selectedanswer'] ?? "",
      correctanswer: map['correctanswer'] ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalquestions': question,
      'selectedanswer': selectedanswer,
      'correctanswer': correctanswer,
    };
  }

  compleveldetails copyWith({
    String? question,
    String? selectedanswer,
    String? correctanswer,
  }) {
    return compleveldetails(
      question: question ?? this.question,
      selectedanswer: selectedanswer ?? this.selectedanswer,
      correctanswer: correctanswer ?? this.correctanswer,
    );
  }
}
