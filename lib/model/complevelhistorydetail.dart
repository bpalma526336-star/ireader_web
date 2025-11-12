class compleveldetails {
  final String question;
  final String complevel;
  final String selectedanswer;
  final String correctanswer;
  final String incorrectanswer;

  compleveldetails({
    required this.question,
    required this.complevel,
    required this.selectedanswer,
    required this.correctanswer,
    required this.incorrectanswer,
  });

  factory compleveldetails.fromMap(Map<String, dynamic> map) {
    return compleveldetails(
      question: map['totalquestions'] ?? "",
      complevel: map['complevel'] ?? "",
      selectedanswer: map['selectedanswer'] ?? "",
      correctanswer: map['correctanswer'] ?? "",
      incorrectanswer: map['incorrectanswer'] ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalquestions': question,
      'complevel': complevel,
      'selectedanswer': selectedanswer,
      'correctanswer': correctanswer,
      'incorrectanswer': incorrectanswer,
    };
  }

  compleveldetails copyWith({
    String? question,
    String? complevel,
    String? selectedanswer,
    String? correctanswer,
    String? incorrectanswer,
  }) {
    return compleveldetails(
      question: question ?? this.question,
      complevel: complevel ?? this.complevel,
      selectedanswer: selectedanswer ?? this.selectedanswer,
      correctanswer: correctanswer ?? this.correctanswer,
      incorrectanswer: incorrectanswer ?? this.incorrectanswer,
    );
  }
}
