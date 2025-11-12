import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/practice_set.dart';
import 'package:ireader_web/model/practicesetcontent.dart';
import 'package:ireader_web/theme.dart';

class EditPracticeSet extends StatefulWidget {
  final PracticeSet practiceSet;
  const EditPracticeSet({super.key, required this.practiceSet});

  @override
  State<EditPracticeSet> createState() => _EditPracticeSetState();
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

class _EditPracticeSetState extends State<EditPracticeSet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController titleController;
  late TextEditingController readingpassageController;
  late TextEditingController timeLimitController;
  late TextEditingController categoryController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late List<QuestionFormItem> questionsItems;
  bool _isLoading = false;

  final List<String> categories = [
    "Frustration",
    "Instructional",
    "Independent",
  ];
  late String? selectedCategory;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void dispose() {
    titleController.dispose();
    readingpassageController.dispose();
    categoryController.dispose();
    timeLimitController.dispose();
    for (var item in questionsItems) {
      item.dispose();
    }
  }

  void _initData() {
    titleController = TextEditingController(text: widget.practiceSet.title);
    readingpassageController = TextEditingController(
      text: widget.practiceSet.readingpassage,
    );
    selectedCategory = widget.practiceSet.category;
    timeLimitController = TextEditingController(
      text: widget.practiceSet.timeLimit.toString(),
    );

    questionsItems = widget.practiceSet.questions.map((PracticeSetContent) {
      return QuestionFormItem(
        questionController: TextEditingController(
          text: PracticeSetContent.questiontext,
        ),
        optionController: PracticeSetContent.options
            .map((option) => TextEditingController(text: option))
            .toList(),
        correctOptionIndex: PracticeSetContent.correctOptionIndex,
      );
    }).toList();
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

  Future<void> _updateQuiz() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
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

      final updateQuiz = widget.practiceSet.copyWith(
        title: titleController.text.trim(),
        readingpassage: readingpassageController.text.trim(),
        timeLimit: int.parse(timeLimitController.text),
        questions: questions,
      );

      await _firestore
          .collection("practiceset")
          .doc(widget.practiceSet.id)
          .update(updateQuiz.toMap(isUpdate: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Practice Set Updated Successfully")),
      );
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Practice Set update successfully",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to update Practice Set",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          "Edit Practice Set",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _updateQuiz,
            icon: Icon(Icons.save, color: AppTheme.primaryColor),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            Text(
              "Edit Practice Set Content",
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
                prefixIcon: Icon(Icons.title, color: AppTheme.primaryColor),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter quiz title";
                }
                return null;
              },
            ),
            SizedBox(height: 16),
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
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedCategory,
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
                prefixIcon: Icon(Icons.category, color: AppTheme.primaryColor),
              ),
            ),
            TextFormField(
              controller: readingpassageController,
              decoration: InputDecoration(
                labelText: "Reading Passage",
                hintText: "Enter Reading Passage",
                alignLabelWithHint: true,
                prefixIcon: Icon(
                  Icons.read_more_outlined,
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          SizedBox(height: 16),
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
                          SizedBox(height: 16),
                          ...question.optionController.asMap().entries.map((
                            entry,
                          ) {
                            final optionIndex = entry.key;
                            final controller = entry.value;

                            return Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Radio<int>(
                                    activeColor: AppTheme.primaryColor,
                                    value: optionIndex,
                                    groupValue: question.correctOptionIndex,
                                    onChanged: (value) {
                                      setState(() {
                                        question.correctOptionIndex = value!;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: controller,
                                      decoration: InputDecoration(
                                        labelText: "Option ${optionIndex + 1} ",
                                        hintText: "Enter Option",
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
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
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateQuiz,
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
                              "Update Practice Set",
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
      ),
    );
  }
}
