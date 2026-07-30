import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/sentences.dart';
import 'package:ireader_web/model/sentencesquestion.dart';
import 'package:ireader_web/theme.dart';

class EditSentences extends StatefulWidget {
  final sentencespracticeset sentencepracticesets;
  const EditSentences({super.key, required this.sentencepracticesets});

  @override
  State<EditSentences> createState() => _EditSentencesState();
}

class QuestionFormItem {
  final TextEditingController questionController;
  final List<TextEditingController> optionController;
  int correctOptionIndex;

  QuestionFormItem({
    required this.questionController,
    required this.optionController,
    required this.correctOptionIndex,
  });

  void dispose() {
    questionController.dispose();
    for (var element in optionController) {
      element.dispose();
    }
  }
}

class _EditSentencesState extends State<EditSentences> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController titleController = TextEditingController();
  late TextEditingController gradelevelController = TextEditingController();
  late TextEditingController categoryController = TextEditingController();
  late TextEditingController visibilityController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late List<QuestionFormItem> questionsItems = [];
  bool _isLoading = false;
  final List<String> gradelevel = ["Grade 1", "Grade 2"];
  late String? selectedgradelevel;
  final List<String> categories = [
    "Frustration",
    "Instructional",
    "Independent",
  ];
  late String? selectedCategory;

  final List<String> visibility = ["View to Students", "Hide from Students"];
  late String? selectedvisibility;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    titleController = TextEditingController(
      text: widget.sentencepracticesets.title,
    );
    selectedgradelevel = widget.sentencepracticesets.gradelevel;
    selectedvisibility = widget.sentencepracticesets.visibility;
    selectedCategory = widget.sentencepracticesets.category;
    questionsItems = widget.sentencepracticesets.questions.map((
      sentencesquestion,
    ) {
      return QuestionFormItem(
        questionController: TextEditingController(
          text: sentencesquestion.questiontext,
        ),
        optionController: sentencesquestion.options
            .map((option) => TextEditingController(text: option))
            .toList(),
        correctOptionIndex: sentencesquestion.correctOptionIndexes,
      );
    }).toList();
  }

  @override
  void dispose() {
    titleController.dispose();
    categoryController.dispose();
    gradelevelController.dispose();
    for (var item in questionsItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      questionsItems.add(
        QuestionFormItem(
          questionController: TextEditingController(),
          optionController: List.generate(4, (e) => TextEditingController()),
          correctOptionIndex: 0,
        ),
      );
    });
  }

  void _removeQuestion(int index) {
    if (questionsItems.length > 1) {
      setState(() {
        questionsItems[index].dispose();
        questionsItems.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Quiz must have at least one question")),
      );
    }
  }

  Future<void> UpdatePhraseSentencePracticeSet() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final questions = questionsItems
          .map(
            (item) => sentencequestions(
              questiontext: item.questionController.text.trim(),
              options: item.optionController.map((e) => e.text.trim()).toList(),
              correctOptionIndexes: item.correctOptionIndex,
            ),
          )
          .toList();
      final sentencespracticesets = sentencespracticeset(
        id: widget.sentencepracticesets.id,
        sectionid: widget.sentencepracticesets.sectionid,
        schoolyearid: widget.sentencepracticesets.schoolyearid,
        title: titleController.text.trim(),
        category: selectedCategory!,
        gradelevel: selectedgradelevel!,
        visibility: selectedvisibility!,
        questions: questions,
      );

      await _firestore
          .collection('phrasesentencespracticeset')
          .doc(sentencespracticesets.id)
          .update(sentencespracticesets.toMap(isUpdate: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phrase/Sentence Practice Set Updated")),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        actions: [
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isMobileS = screenWidth <= 768;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: isMobileS
                    // 🔥 ICON ONLY (Mobile S 320px)
                    ? IconButton(
                        icon: const Icon(Icons.update),
                        color: Colors.green,
                        tooltip: "Update Phrase and Sentence Practice Set",
                        onPressed: _isLoading
                            ? null
                            : UpdatePhraseSentencePracticeSet,
                      )
                    // 🔥 ICON + LABEL (Tablet/Desktop)
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.update, size: 20),
                        label: const Text(
                          'Update Phrase and Sentence Practice Set',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isLoading
                            ? null
                            : UpdatePhraseSentencePracticeSet,
                      ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            Text(
              "Edit Phrase and Sentence Practice Set Content",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: titleController,
              decoration: InputDecoration(
                fillColor: Colors.white,
                labelText: "Title",
                hintText: "Enter quiz title",
                prefixIcon: Icon(Icons.title, color: Colors.green),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter quiz title";
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedgradelevel,
              items: gradelevel.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedgradelevel = value;
                });
              },
              decoration: InputDecoration(
                labelText: "Grade Level",
                prefixIcon: Icon(Icons.grade, color: Colors.green),
              ),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              items: categories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                });
              },
              decoration: InputDecoration(
                labelText: "Category",
                prefixIcon: Icon(Icons.category, color: Colors.green),
              ),
            ),
            SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Questions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _addQuestion,
                      label: Text("Add Question"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ...questionsItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final QuestionFormItem question = entry.value;

                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Question ${index + 1}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              if (questionsItems.length > 1)
                                IconButton(
                                  onPressed: () {
                                    _removeQuestion(index);
                                  },
                                  icon: Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: question.questionController,
                            decoration: InputDecoration(
                              labelText: "Question",
                              hintText: "Enter question",
                              prefixIcon: Icon(
                                Icons.question_mark,
                                color: Colors.green,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please enter question";
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          ...question.optionController.asMap().entries.map((
                            entry,
                          ) {
                            final optionIndex = entry.key;
                            final controller = entry.value;

                            return Row(
                              children: [
                                Radio<int>(
                                  value: optionIndex,
                                  groupValue: question.correctOptionIndex,
                                  onChanged: (value) {
                                    setState(() {
                                      question.correctOptionIndex = value!;
                                    });
                                  },
                                  activeColor: Colors.green,
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: controller,
                                    decoration: InputDecoration(
                                      labelText: "Option ${optionIndex + 1}",
                                    ),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                        ? "Enter option"
                                        : null,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
