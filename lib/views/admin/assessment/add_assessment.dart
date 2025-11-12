import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ireader_web/model/assessment.dart';
import 'package:ireader_web/model/assessmentcontent.dart';
import 'package:ireader_web/model/schoolyear.dart';
import 'package:ireader_web/theme.dart';
import 'package:ireader_web/views/admin/assessment/manage_assessment.dart';

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
  final TextEditingController complevelcontroller;
  final List<TextEditingController> optionsControllers;
  int correctoptionindex;

  QuestionFormItem({
    required this.questionController,
    required this.complevelcontroller,
    required this.optionsControllers,
    required this.correctoptionindex,
  });

  void dispose() {
    questionController.dispose();
    optionsControllers.forEach((element) {
      element.dispose();
    });
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
  final _timeopen = TextEditingController();
  final _timeclose = TextEditingController();
  final _accesscodecontroller = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  bool _isloading = false;
  List<QuestionFormItem> _questionItems = [];
  final List<String> visibility = ["View to Students", "Hide from Students"];
  String? selectedvisibility;
  final List<String> assessmenttitle = [
    "Stage 2 - Pre-Test",
    "Stage 3 - Midway/Mid-test",
    "Stage 4 - Post-Test",
  ];
  String? selectedassessmenttitle;
  List<QuestionFormItem> questionsItems = [];

  @override
  void dispose() {
    _assessmenttitlecontroller.dispose();
    _titlereadingpassagecontroller.dispose();
    _readingpassagecontentcontroller.dispose();
    _timelimit.dispose();
    _date.dispose();
    _timeopen.dispose();
    _timeclose.dispose();
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
          complevelcontroller: TextEditingController(),
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
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please fill in all required fields"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    for (var q in _questionItems) {
      if (q.questionController.text.trim().isEmpty ||
          q.optionsControllers.any((o) => o.text.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please complete all questions and options"),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() => _isloading = true);

    try {
      final questions = _questionItems
          .map(
            (item) => AssessmentContent(
              questiontext: item.questionController.text.trim(),
              complevel: item.complevelcontroller.text.trim(),
              options: item.optionsControllers
                  .map((e) => e.text.trim())
                  .toList(),
              correctoptionindex: item.correctoptionindex,
            ),
          )
          .toList();
      await _firestore
          .collection("practiceset")
          .doc()
          .set(
            Assessment(
              id: _firestore.collection("assessment").doc().id,
              schoolyearid: widget.schoolyear.id,
              assessmenttitle: _assessmenttitlecontroller.text.trim(),
              visibility: _visibilityController.text.trim(),
              timelimit: int.parse(_timelimit.text.trim()),
              date: _date.text.trim(),
              timeopen: _timeopen.text.trim(),
              timeclose: _timeclose.text.trim(),
              accesscode: _accesscodecontroller.text.trim(),
              readingpassagetitle: _titlereadingpassagecontroller.text.trim(),
              readingpassagecontent: _readingpassagecontentcontroller.text
                  .trim(),
              questions: questions,
            ).toMap(),
          );
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => ManageAssessment(schoolyear: widget.schoolyear),
      //   ),
      // );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Section added successfully')),
        );
        Navigator.pop(context); // ✅ return to Manage Section
      }
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
        _isloading = false;
      });
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
        title: Text(
          "Add Practice Set Content",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ElevatedButton.icon(
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
            Text(
              "Assessment Test Content Form",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedassessmenttitle,
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
                fillColor: Colors.white,
                labelText: "Reading Passage Title",
                hintText: "Enter Reading Passage Title",
                prefixIcon: Icon(Icons.title, color: AppTheme.primaryColor),
                border: OutlineInputBorder(),
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
            TextFormField(
              controller: _accesscodecontroller,
              decoration: InputDecoration(
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 20),
                labelText: "Access Code",
                hintText: "Enter Access Code",
                prefixIcon: Icon(Icons.password, color: AppTheme.primaryColor),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter time limit";
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
                        "${pickedDate.year}-${pickedDate.month}-${pickedDate.day}";
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
            TextFormField(
              controller: _timeopen,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Open Time",
                hintText: "Select Time to Open",
                prefixIcon: Icon(
                  Icons.access_time,
                  color: AppTheme.primaryColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onTap: () async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (pickedTime != null) {
                  setState(() {
                    _timeopen.text = pickedTime.format(context);
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please select open time";
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: _timeclose,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Close Time",
                hintText: "Select Time to Close",
                prefixIcon: Icon(
                  Icons.lock_clock,
                  color: AppTheme.primaryColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onTap: () async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (pickedTime != null) {
                  setState(() {
                    _timeclose.text = pickedTime.format(context);
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please select close time";
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
                          TextFormField(
                            controller: question.complevelcontroller,
                            decoration: InputDecoration(
                              labelText: "Comprehension Level",
                              hintText: "Enter Comprehension Level",
                              prefixIcon: Icon(
                                Icons.leaderboard,
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
                                    activeColor: AppTheme.primaryColor,
                                    value: optionIndex,
                                    groupValue: question.correctoptionindex,
                                    onChanged: (value) {
                                      setState(() {
                                        question.correctoptionindex = value!;
                                      });
                                    },
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
