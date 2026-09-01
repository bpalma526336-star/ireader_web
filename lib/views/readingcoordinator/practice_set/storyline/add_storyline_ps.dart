import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/model/section.dart';
import 'package:ireader_web/model/storyline_practice_set.dart';
import 'package:ireader_web/model/storyline_practice_set_content.dart';
import 'package:ireader_web/theme.dart';

class AddSlps extends StatefulWidget {
  final Section section;
  final SchoolYear schoolyear;
  const AddSlps({super.key, required this.section, required this.schoolyear});

  @override
  State<AddSlps> createState() => _AddSlpsState();
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
    for (var c in optionController) {
      c.dispose();
    }
  }
}

class _AddSlpsState extends State<AddSlps> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final readingpassageController = TextEditingController();
  final gradelevelController = TextEditingController();
  final categoryController = TextEditingController();
  final visibilityController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<QuestionFormItem> questionsItems = [];
  bool _isLoading = false;
  final List<String> gradelevel = ["Grade 1", "Grade 2"];
  String? selectedgradelevel;
  final List<String> categories = [
    "Frustration",
    "Instructional",
    "Independent",
  ];
  String? selectedCategory;

  final List<String> visibility = ["View to Students", "Hide from Students"];
  String? selectedvisibility;

  @override
  void initState() {
    super.initState();
    _addQuestion();
  }

  @override
  void dispose() {
    titleController.dispose();
    gradelevelController.dispose();
    categoryController.dispose();
    readingpassageController.dispose();
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

  Future<void> SaveStorylinePracticeSet() async {
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
            (item) => StorylinePracticeSetContent(
              questiontext: item.questionController.text.trim(),
              options: item.optionController.map((c) => c.text.trim()).toList(),
              correctOptionIndex: item.correctOptionIndex,
            ),
          )
          .toList();
      await _firestore
          .collection("storylinepracticeset")
          .doc()
          .set(
            StorylinePracticeSet(
              id: _firestore.collection("storylinepracticeset").doc().id,
              sectionid: widget.section.id,
              schoolyearid: widget.schoolyear.id,
              title: titleController.text.trim(),
              category: categoryController.text.trim(),
              gradelevel: gradelevelController.text.trim(),
              visibility: visibilityController.text.trim(),
              readingpassage: readingpassageController.text.trim(),
              questions: questions,
            ).toMap(),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Practice Set added successfully",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
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
      if (!mounted) return;
      Navigator.pop(context);
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
                        icon: const Icon(Icons.save),
                        color: Colors.purple,
                        tooltip: "Save Storyline Practice Set",
                        onPressed: _isLoading ? null : SaveStorylinePracticeSet,
                      )
                    // 🔥 ICON + LABEL (Tablet/Desktop)
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.save, size: 20),
                        label: const Text('Save Storyline Practice Set'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
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
                        onPressed: _isLoading ? null : SaveStorylinePracticeSet,
                      ),
              );
            },
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
                    labelText: "Title",
                    hintText: "Enter Practice Set Title",
                    prefixIcon: Icon(Icons.title, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
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
                  initialValue: selectedvisibility,
                  decoration: InputDecoration(
                    labelText: "Visibility",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(
                      Icons.remove_red_eye,
                      color: Colors.purple,
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
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: "Category",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.category, color: Colors.purple),
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
                DropdownButtonFormField<String>(
                  initialValue: selectedgradelevel,
                  decoration: InputDecoration(
                    labelText: "Grade Level",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.grade, color: Colors.purple),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: gradelevel.map((gradelevel) {
                    return DropdownMenuItem<String>(
                      value: gradelevel,
                      child: Text(gradelevel),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedgradelevel = value;
                      gradelevelController.text = value ?? "";
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please Select Grade Level";
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
                    prefixIcon: Icon(Icons.read_more, color: Colors.purple),
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
                            backgroundColor: Colors.purple,
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
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Question ${index + 1}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                    ),
                                  ),
                                  if (questionsItems.length > 1)
                                    IconButton(
                                      onPressed: () => _removeQuestion(index),
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                ],
                              ),
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
                              TextFormField(
                                controller: question.questionController,
                                decoration: InputDecoration(
                                  labelText: "Question",
                                  hintText: "Enter question",
                                  prefixIcon: Icon(
                                    Icons.question_mark,
                                    color: Colors.purple,
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? "Please enter question"
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              ...question.optionController.asMap().entries.map((
                                optEntry,
                              ) {
                                final optIndex = optEntry.key;
                                final controller = optEntry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Radio<int>(
                                        value: optIndex,
                                        groupValue: question.correctOptionIndex,
                                        onChanged: (value) {
                                          setState(() {
                                            question.correctOptionIndex =
                                                value!;
                                          });
                                        },
                                        activeColor: Colors.purple,
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          controller: controller,
                                          decoration: InputDecoration(
                                            labelText: "Option ${optIndex + 1}",
                                            hintText: "Enter Option",
                                          ),
                                          validator: (v) =>
                                              (v == null || v.isEmpty)
                                              ? "Please enter option"
                                              : null,
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
