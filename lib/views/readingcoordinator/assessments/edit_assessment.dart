import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/assessment.dart';
import 'package:ireader_web/model/assessmentcontent.dart';
import 'package:ireader_web/theme.dart';

class EditAssessmentScreen extends StatefulWidget {
  final Assessment assessment;
  const EditAssessmentScreen({super.key, required this.assessment});

  @override
  State<EditAssessmentScreen> createState() => _EditAssessmentScreenState();
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

class _EditAssessmentScreenState extends State<EditAssessmentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController assessmenttitleController;
  late TextEditingController visibilityController;
  late TextEditingController titlereadingController;
  late TextEditingController readingpassagecontentController;
  late TextEditingController timelimitcontroller;
  late TextEditingController datecontroller;
  late TextEditingController accesscodecontroller;
  late List<QuestionFormItem> questionFormItems;
  bool _isLoading = false;
  final List<String> visibility = ["View to Students", "Hide from Students"];
  late String? selectedvisibility;
  final List<String> assessmenttitle = [
    "Stage 2 - Pre-Test",
    "Stage 3 - Midway/Mid-test",
    "Stage 4 - Post-Test",
  ];
  late String? selectedassessmenttitle;
  String? selectedreadingcomplevel;
  final List<String> readingcomplevel = ["Literal", "Inferential", "Critical"];
  int _wordCount = 0;
  int countWords(String text) {
    if (text.trim().isEmpty) return 0;

    final words = text.trim().split(RegExp(r'\s+'));
    return words.length;
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void dispose() {
    assessmenttitleController.dispose();
    visibilityController.dispose();
    titlereadingController.dispose();
    readingpassagecontentController.dispose();
    timelimitcontroller.dispose();
    datecontroller.dispose();
    accesscodecontroller.dispose();
    for (var item in questionFormItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      questionFormItems.add(
        QuestionFormItem(
          questionController: TextEditingController(),
          optionController: List.generate(4, (e) => TextEditingController()),
          correctOptionIndex: 0,
        ),
      );
    });
  }

  void _removeQuestion(int index) {
    if (questionFormItems.length > 1) {
      setState(() {
        questionFormItems[index].dispose();
        questionFormItems.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Quiz must have at least one question")),
      );
    }
  }

  Future<void> _updateAssessment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final wordCount = countWords(readingpassagecontentController.text);
      final questions = questionFormItems
          .map(
            (item) => AssessmentContent(
              questiontext: item.questionController.text.trim(),
              options: item.optionController.map((e) => e.text.trim()).toList(),
              correctoptionindex: item.correctOptionIndex,
            ),
          )
          .toList();

      final updateQuiz = widget.assessment.copywith(
        assessmenttitle: selectedassessmenttitle,
        visibility: selectedvisibility,
        timelimit: int.parse(timelimitcontroller.text.trim()),
        date: datecontroller.text.trim(),
        accesscode: accesscodecontroller.text.trim(),
        readingpassagetitle: titlereadingController.text.trim(),
        readingpassagecontent: readingpassagecontentController.text.trim(),
        totalwords: wordCount,
        questions: questions,
      );

      await _firestore
          .collection("assessment")
          .doc(widget.assessment.id)
          .update(updateQuiz.toMap(isUpdate: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Assessment Updated Successfully")),
      );
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Assessment update successfully",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to update Assessment",
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

  void _initData() {
    assessmenttitleController = TextEditingController(
      text: widget.assessment.assessmenttitle,
    );
    visibilityController = TextEditingController(
      text: widget.assessment.visibility,
    );
    titlereadingController = TextEditingController(
      text: widget.assessment.readingpassagetitle,
    );
    readingpassagecontentController = TextEditingController(
      text: widget.assessment.readingpassagecontent,
    );
    timelimitcontroller = TextEditingController(
      text: widget.assessment.timelimit.toString(),
    );
    datecontroller = TextEditingController(text: widget.assessment.date);
    accesscodecontroller = TextEditingController(
      text: widget.assessment.accesscode,
    );

    selectedvisibility = widget.assessment.visibility;
    selectedassessmenttitle = widget.assessment.assessmenttitle;

    questionFormItems = widget.assessment.questions.map((AssessmentContent) {
      return QuestionFormItem(
        questionController: TextEditingController(
          text: AssessmentContent.questiontext,
        ),
        optionController: AssessmentContent.options
            .map((option) => TextEditingController(text: option))
            .toList(),
        correctOptionIndex: AssessmentContent.correctoptionindex,
      );
    }).toList();
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
              final isMobileS = screenWidth <= 320;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: isMobileS
                    // 🔥 ICON ONLY (Mobile S 320px)
                    ? IconButton(
                        icon: const Icon(Icons.update),
                        color: AppTheme.primaryColor,
                        tooltip: "Update Assessment",
                        onPressed: _isLoading ? null : _updateAssessment,
                      )
                    // 🔥 ICON + LABEL (Tablet/Desktop)
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.update, size: 20),
                        label: const Text('Update Assessment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
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
                        onPressed: _isLoading ? null : _updateAssessment,
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
            AutoSizeText(
              "Edit Assessment Content Form",
              style: TextStyle(color: AppTheme.textPrimaryColor),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedassessmenttitle,
              items: assessmenttitle.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedassessmenttitle = value;
                });
              },
              decoration: InputDecoration(
                labelText: "Assessment Title",
                prefixIcon: Icon(Icons.grade, color: AppTheme.primaryColor),
              ),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedvisibility,
              items: visibility.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedvisibility = value;
                });
              },
              decoration: InputDecoration(
                labelText: "Visibility",
                prefixIcon: Icon(
                  Icons.visibility,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: titlereadingController,
              decoration: InputDecoration(
                fillColor: Colors.white,
                labelText: "Reading Passage Title",
                hintText: "Enter quiz title",
                prefixIcon: Icon(Icons.title, color: AppTheme.primaryColor),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please Enter Reading Passage Title";
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: readingpassagecontentController,
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
            TextFormField(
              controller: timelimitcontroller,
              decoration: InputDecoration(
                labelText: "Time Limit (in minutes)",
                prefixIcon: Icon(Icons.timer, color: AppTheme.primaryColor),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please Enter Time Limit";
                }
                if (int.tryParse(value) == null) {
                  return "Please Enter a valid number";
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: accesscodecontroller,
              decoration: InputDecoration(
                labelText: "Access Code",
                hintText: "Enter Access Code",
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 20),
                prefixIcon: Icon(Icons.lock, color: AppTheme.primaryColor),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please Enter Access Code";
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: datecontroller,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Assessment Date",
                hintText: "Select Assessment Date",
                prefixIcon: Icon(
                  Icons.calendar_today,
                  color: AppTheme.primaryColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onTap: () async {
                final DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    datecontroller.text =
                        "${pickedDate.month}-${pickedDate.day}-${pickedDate.year}";
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please Select a date";
                }
                return null;
              },
            ),
            SizedBox(height: 20),
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
                ...questionFormItems.asMap().entries.map((entry) {
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
                              if (questionFormItems.length > 1)
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
                                    value: optionIndex,
                                    groupValue: question.correctOptionIndex,
                                    onChanged: (value) {
                                      setState(() {
                                        question.correctOptionIndex = value!;
                                      });
                                    },
                                    activeColor: AppTheme.primaryColor,
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
