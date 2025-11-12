import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/practice_set.dart';
import 'package:ireader_web/model/practicesetcontent.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/readingcoordinator/practiceset/manage_practice_set.dart';

class AddPracticeSet extends StatefulWidget {
  const AddPracticeSet({super.key});

  @override
  State<AddPracticeSet> createState() => _AddPracticeSetState();
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
    optionController.forEach((element) {
      element.dispose();
    });
  }
}

class _AddPracticeSetState extends State<AddPracticeSet> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final readingpassageController = TextEditingController();
  final timeLimitController = TextEditingController();
  final categoryController = TextEditingController();
  final visibilityController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<QuestionFormItem> questionsItems = [];
  bool _isLoading = false;

  final List<String> categories = [
    "Frustration",
    "Instructional",
    "Independent",
  ];
  String? selectedCategory;

  final List<String> visibility = ["View to Students", "Hide from Students"];
  String? selectedvisibility;

  @override
  void dispose() {
    titleController.dispose();
    timeLimitController.dispose();
    categoryController.dispose();
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
          optionController: List.generate(4, (_) => TextEditingController()),
          correctOptionIndex: 0,
        ),
      );
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      questionsItems[index].dispose();
      questionsItems.removeAt(index);
    });
  }

  Future<void> SavePracticeSet() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please fill in all required fields"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    for (var q in questionsItems) {
      if (q.questionController.text.trim().isEmpty ||
          q.optionController.any((o) => o.text.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please complete all questions and options"),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final questions = questionsItems
          .map(
            (item) => PracticeSetContent(
              questiontext: item.questionController.text.trim(),
              options: item.optionController.map((e) => e.text.trim()).toList(),
              correctOptionIndex: item.correctOptionIndex,
            ),
          )
          .toList();
      await _firestore
          .collection("practiceset")
          .doc()
          .set(
            PracticeSet(
              id: _firestore.collection("practiceset").doc().id,
              title: titleController.text.trim(),
              category: categoryController.text.trim(),
              visibility: visibilityController.text.trim(),
              readingpassage: readingpassageController.text.trim(),
              timeLimit: int.parse(timeLimitController.text.trim()),
              questions: questions,
            ).toMap(),
          );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Practice Set added successfully",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ManagePracticeSet()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to Add Practice Sets",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showDiscardConfirmation() async {
    bool? shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Discard Practice Set"),
          content: Text("Are you sure you want to discard this practice set?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text("CANCEL"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text("DISCARD", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDiscard == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ManagePracticeSet()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          "Add Practice Set Content",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : SavePracticeSet,
            icon: Icon(Icons.save, color: AppTheme.primaryColor),
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back_outlined),
          onPressed: _showDiscardConfirmation,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Practice Set Content Form",
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
                    hintText: "Enter Practice Set Title",
                    prefixIcon: Icon(Icons.title, color: AppTheme.primaryColor),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please Enter Practice Set Title";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedvisibility,
                  decoration: InputDecoration(
                    labelText: "Visibility",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(
                      Icons.remove_red_eye,
                      color: AppTheme.primaryColor,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: visibility.map((visibility) {
                    return DropdownMenuItem<String>(
                      value: visibility,
                      child: Text(visibility),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedvisibility = value;
                      visibilityController.text = value ?? "";
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please Select Visibility";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: "Category",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(
                      Icons.category,
                      color: AppTheme.primaryColor,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value;
                      categoryController.text = value ?? "";
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please select a category";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: readingpassageController,
                  decoration: InputDecoration(
                    labelText: "Reading Passage",
                    hintText: "Enter Reading Passage",
                    alignLabelWithHint: true,
                    prefixIcon: Icon(
                      Icons.read_more,
                      color: AppTheme.primaryColor,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: EdgeInsets.all(16),
                  ),
                  keyboardType: TextInputType.multiline,
                  minLines: 5,
                  maxLines: null,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please Enter Reading Passage";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: timeLimitController,
                  decoration: InputDecoration(
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(vertical: 20),
                    labelText: "Time Limit (in minutes)",
                    hintText: "Enter Time Limit",
                    prefixIcon: Icon(Icons.timer, color: AppTheme.primaryColor),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter time limit";
                    }
                    final number = int.tryParse(value);
                    if (number == null || number <= 0) {
                      return "Please enter a valid time limit";
                    }
                    return null;
                  },
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
                            backgroundColor: AppTheme.primaryColor,
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
                              // Top row with Question label + delete button
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Question ${index + 1}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
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

                              // Instruction for older users
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4.0,
                                  bottom: 12.0,
                                ),
                                child: Text(
                                  "To choose the correct answer, tap the small round button beside it.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ),

                              // Question textfield
                              TextFormField(
                                controller: question.questionController,
                                decoration: InputDecoration(
                                  labelText: "Question",
                                  hintText: "Enter question",
                                  prefixIcon: Icon(
                                    Icons.question_mark,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please enter question";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Options with radio buttons
                              ...question.optionController.asMap().entries.map((
                                entry,
                              ) {
                                final optionIndex = entry.key;
                                final controller = entry.value;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Radio<int>(
                                        activeColor: AppTheme.primaryColor,
                                        value: optionIndex,
                                        groupValue: question.correctOptionIndex,
                                        onChanged: (value) {
                                          setState(() {
                                            question.correctOptionIndex =
                                                value!;
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          controller: controller,
                                          decoration: InputDecoration(
                                            labelText:
                                                "Option ${optionIndex + 1}",
                                            hintText: "Enter option",
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return "Please enter option";
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: 32),
                    Center(
                      child: SizedBox(
                        height: 50,
                        width: 200,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : SavePracticeSet,
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "Save Practice Set",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
