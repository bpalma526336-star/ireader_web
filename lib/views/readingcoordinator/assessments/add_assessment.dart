import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/assessment.dart';
import 'package:ireader_web/model/assessmentcontent.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/theme.dart';

class AddAssessmentScreen extends StatefulWidget {
  final SchoolYear schoolyear;
  final String? schoolyearid;
  const AddAssessmentScreen({
    super.key,
    required this.schoolyear,
    required this.schoolyearid,
  });

  @override
  State<AddAssessmentScreen> createState() => _AddAssessmentScreenState();
}

class QuestionFormItem {
  final TextEditingController questionController;
  final List<TextEditingController> optionsControllers;
  int correctoptionindex;

  QuestionFormItem({
    required this.questionController,
    required this.optionsControllers,
    required this.correctoptionindex,
  });

  void dispose() {
    questionController.dispose();
    for (var element in optionsControllers) {
      element.dispose();
    }
  }
}

class _AddAssessmentScreenState extends State<AddAssessmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assessmenttitlecontroller = TextEditingController();
  final _visibilityController = TextEditingController();
  final _titlereadingpassagecontroller = TextEditingController();

  final _readingpassagecontentcontroller = TextEditingController();
  final _timelimit = TextEditingController();
  final _date = TextEditingController();
  final _accesscodecontroller = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  bool _isloading = false;
  final List<QuestionFormItem> _questionItems = [];
  final List<String> visibility = ["View to Students", "Hide from Students"];
  String? selectedvisibility;
  final List<String> assessmenttitle = [
    "Stage 2 - Pre-Test",
    "Stage 3 - Midway/Mid-test",
    "Stage 4 - Post-Test",
  ];
  String? selectedassessmenttitle;
  int _wordCount = 0;

  int countWords(String text) {
    if (text.trim().isEmpty) return 0;

    final words = text.trim().split(RegExp(r'\s+'));
    return words.length;
  }

  @override
  void initState() {
    super.initState();
    // Ensure the form starts with one question
    _addQuestion();
  }

  @override
  void dispose() {
    _assessmenttitlecontroller.dispose();
    _titlereadingpassagecontroller.dispose();
    _readingpassagecontentcontroller.dispose();
    _timelimit.dispose();
    _date.dispose();
    _accesscodecontroller.dispose();
    for (var item in _questionItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questionItems.add(
        QuestionFormItem(
          questionController: TextEditingController(),
          optionsControllers: List.generate(4, (_) => TextEditingController()),
          correctoptionindex: 0,
        ),
      );
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questionItems[index].dispose();
      _questionItems.removeAt(index);
    });
  }

  Future<void> _SaveAssessment() async {
    // Basic form validation
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all required fields"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_questionItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add at least one question"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Ensure all questions & options are complete
    for (var q in _questionItems) {
      if (q.questionController.text.trim().isEmpty ||
          q.optionsControllers.any((o) => o.text.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please complete all questions and options"),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    // Prevent duplicate titles within the same school year
    try {
      final assessmentexist = await _firestore
          .collection("assessment")
          .where(
            "assessmenttitle",
            isEqualTo: _assessmenttitlecontroller.text.trim(),
          )
          .where('schoolyearid', isEqualTo: widget.schoolyear.id)
          .get();

      if (assessmentexist.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "An assessment with this title already exists for the selected school year.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to validate assessment title: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // All checks passed — save
    setState(() => _isloading = true);
    try {
      final questions = _questionItems
          .map(
            (item) => AssessmentContent(
              questiontext: item.questionController.text.trim(),
              options: item.optionsControllers
                  .map((e) => e.text.trim())
                  .toList(),
              correctoptionindex: item.correctoptionindex,
            ),
          )
          .toList();

      final docRef = _firestore.collection("assessment").doc();
      await docRef.set(
        Assessment(
          id: docRef.id,
          schoolyearid: widget.schoolyear.id,
          assessmenttitle: _assessmenttitlecontroller.text.trim(),
          visibility: _visibilityController.text.trim(),
          timelimit: int.tryParse(_timelimit.text.trim()) ?? 0,
          date: _date.text.trim(),
          accesscode: _accesscodecontroller.text.trim(),
          readingpassagetitle: _titlereadingpassagecontroller.text.trim(),
          readingpassagecontent: _readingpassagecontentcontroller.text.trim(),
          totalwords: _wordCount,
          questions: questions,
        ).toMap(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assessment added successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save assessment: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isloading = false);
    }
  }

  Future<void> _showDiscardConfirmation() async {
    bool? shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Discard Assessment"),
          content: Text("Are you sure you want to discard this Assessment?"),
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
              final isMobileS = screenWidth <= 320;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: isMobileS
                    // 🔥 ICON ONLY (Mobile S 320px)
                    ? IconButton(
                        icon: const Icon(Icons.save),
                        color: AppTheme.primaryColor,
                        tooltip: "Save Assessment",
                        onPressed: _isloading ? null : _SaveAssessment,
                      )
                    // 🔥 ICON + LABEL (Tablet/Desktop)
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.save, size: 20),
                        label: const Text('Save Assessment'),
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
                        onPressed: _isloading ? null : _SaveAssessment,
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
            AutoSizeText(
              "Create Assessment Test Content Form",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: selectedassessmenttitle,
              decoration: InputDecoration(
                labelText: "Assessment Title",
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
              items: assessmenttitle.map((assessmenttitle) {
                return DropdownMenuItem<String>(
                  value: assessmenttitle,
                  child: Text(assessmenttitle),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedassessmenttitle = value;
                  _assessmenttitlecontroller.text = value ?? "";
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please Select Assessment Title";
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
                  _visibilityController.text = value ?? "";
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
            TextFormField(
              controller: _titlereadingpassagecontroller,
              decoration: InputDecoration(
                labelText: "Reading Passage Title",
                hintText: "Enter Reading Passage Title",
                prefixIcon: Icon(Icons.title, color: AppTheme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Please enter the Assessment Title";
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: _readingpassagecontentcontroller,
              decoration: InputDecoration(
                labelText: "Reading Passage Content",
                hintText: "Enter Reading Passage Content",
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.read_more, color: AppTheme.primaryColor),
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
              onChanged: (value) {
                setState(() {
                  _wordCount = countWords(value);
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please Enter Reading Passage";
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: _timelimit,
              decoration: InputDecoration(
                labelText: "Time Limit (in minutes)",
                hintText: "Enter Time Limit",
                prefixIcon: Icon(Icons.timer, color: AppTheme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
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
            TextFormField(
              controller: _accesscodecontroller,
              decoration: InputDecoration(
                labelText: "Access Code",
                hintText: "Enter Access Code",
                prefixIcon: Icon(Icons.password, color: AppTheme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter Access Code";
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: _date,
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
                    _date.text =
                        "${pickedDate.month}-${pickedDate.day}-${pickedDate.year}";
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please select a date";
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
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
                      icon: const Icon(Icons.add),
                      label: const Text("Add Question"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(140, 36),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ..._questionItems.asMap().entries.map((entry) {
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
                              if (_questionItems.length > 1)
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
                          ...question.optionsControllers.asMap().entries.map((
                            entry,
                          ) {
                            final optionIndex = entry.key;
                            final controller = entry.value;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Radio<int>(
                                    value: optionIndex,
                                    groupValue: question.correctoptionindex,
                                    onChanged: (value) {
                                      setState(() {
                                        question.correctoptionindex = value!;
                                      });
                                    },
                                    activeColor: AppTheme.primaryColor,
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: controller,
                                      decoration: InputDecoration(
                                        labelText: "Option ${optionIndex + 1}",
                                        hintText: "Enter option",
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
