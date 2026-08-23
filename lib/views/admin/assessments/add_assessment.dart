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
    _addQuestion();
  }

  @override
  void dispose() {
    _assessmenttitlecontroller.dispose();
    _visibilityController.dispose();
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

  Future<void> _saveAssessment() async {
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

    // Duplicate title check
    try {
      final assessmentexist = await _firestore
          .collection("assessment")
          .where(
            "assessmenttitle",
            isEqualTo: _assessmenttitlecontroller.text.trim(),
          )
          .where('schoolyearid', isEqualTo: widget.schoolyear.id)
          .get();

      if (!mounted) return;

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to validate assessment title: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save assessment: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isloading = false);
    }
  }

  Future<void> _showDiscardConfirmation() async {
    bool? shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Discard Assessment"),
          content: const Text(
            "Are you sure you want to discard this Assessment?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("CANCEL"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                "DISCARD",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDiscard == true && mounted) {
      Navigator.pop(context);
    }
  }

  // ── Shared card wrapper ──────────────────────────────────────────────────────
  Widget _card({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ── Labelled field wrapper ───────────────────────────────────────────────────
  Widget _labelledField({required String label, required Widget field}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  // ── Input decoration ─────────────────────────────────────────────────────────
  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolYearLabel =
        "${widget.schoolyear.schoolyearstart} – ${widget.schoolyear.schoolyearend}";

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_outlined, color: AppTheme.textPrimaryColor),
          onPressed: _showDiscardConfirmation,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Create Assessment",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            Text(
              "School Year $schoolYearLabel",
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isMobileS = screenWidth <= 320;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: _isloading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : isMobileS
                        ? IconButton(
                            icon: const Icon(Icons.save),
                            color: AppTheme.primaryColor,
                            tooltip: "Save Assessment",
                            onPressed: _saveAssessment,
                          )
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('Save Assessment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _saveAssessment,
                          ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.borderColor),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Card 1: Assessment Info ──────────────────────────────
                  _card(
                    title: "Assessment Info",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Assessment Title dropdown
                        _labelledField(
                          label: "Assessment Title",
                          field: DropdownButtonFormField<String>(
                            initialValue: selectedassessmenttitle,
                            decoration: _inputDecoration(
                              hint: "Select assessment title",
                            ),
                            items: assessmenttitle.map((t) {
                              return DropdownMenuItem<String>(
                                value: t,
                                child: Text(t),
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
                                return "Please select an assessment title";
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Visibility dropdown
                        _labelledField(
                          label: "Visibility",
                          field: DropdownButtonFormField<String>(
                            initialValue: selectedvisibility,
                            decoration: _inputDecoration(
                              hint: "Select visibility",
                            ),
                            items: visibility.map((v) {
                              return DropdownMenuItem<String>(
                                value: v,
                                child: Text(v),
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
                                return "Please select visibility";
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Date + Time Limit row
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 500;
                            final fields = [
                              _labelledField(
                                label: "Assessment Date",
                                field: TextFormField(
                                  controller: _date,
                                  readOnly: true,
                                  decoration: _inputDecoration(
                                    hint: "Select date",
                                  ).copyWith(
                                    suffixIcon: const Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                  onTap: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2100),
                                        );
                                    if (picked != null) {
                                      setState(() {
                                        _date.text =
                                            "${picked.month}-${picked.day}-${picked.year}";
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
                              ),
                              _labelledField(
                                label: "Time Limit (minutes)",
                                field: TextFormField(
                                  controller: _timelimit,
                                  decoration: _inputDecoration(
                                    hint: "e.g. 30",
                                  ).copyWith(
                                    suffixIcon: const Icon(
                                      Icons.timer_outlined,
                                      size: 18,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Please enter time limit";
                                    }
                                    final n = int.tryParse(value);
                                    if (n == null || n <= 0) {
                                      return "Enter a valid time limit";
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ];

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  fields[0],
                                  const SizedBox(height: 16),
                                  fields[1],
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: fields[0]),
                                const SizedBox(width: 16),
                                Expanded(child: fields[1]),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Access Code
                        _labelledField(
                          label: "Access Code",
                          field: TextFormField(
                            controller: _accesscodecontroller,
                            decoration: _inputDecoration(
                              hint: "Enter access code",
                            ).copyWith(
                              suffixIcon: const Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please enter access code";
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Card 2: Reading Passage ──────────────────────────────
                  _card(
                    title: "Reading Passage",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _labelledField(
                          label: "Passage Title",
                          field: TextFormField(
                            controller: _titlereadingpassagecontroller,
                            decoration: _inputDecoration(
                              hint: "Enter reading passage title",
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Please enter the passage title";
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        _labelledField(
                          label: "Passage Content",
                          field: TextFormField(
                            controller: _readingpassagecontentcontroller,
                            decoration: _inputDecoration(
                              hint: "Enter the reading passage text here…",
                            ).copyWith(
                              alignLabelWithHint: true,
                              contentPadding: const EdgeInsets.all(14),
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
                                return "Please enter reading passage content";
                              }
                              return null;
                            },
                          ),
                        ),
                        if (_wordCount > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            "$_wordCount word${_wordCount == 1 ? '' : 's'}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Card 3: Questions ────────────────────────────────────
                  _card(
                    title: "Questions",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Numbered question cards
                        ..._questionItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final question = entry.value;
                          return _buildQuestionCard(index, question);
                        }),

                        const SizedBox(height: 8),

                        // Add Question button
                        OutlinedButton.icon(
                          onPressed: _addQuestion,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Add Question"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(
                              color: AppTheme.primaryColor,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, QuestionFormItem question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Question ${index + 1}",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              if (_questionItems.length > 1)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _removeQuestion(index),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Select the radio button beside the correct answer.",
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 12),

          // Question text field
          TextFormField(
            controller: question.questionController,
            decoration: _inputDecoration(hint: "Enter question text").copyWith(
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please enter the question";
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Option fields with radio buttons
          RadioGroup<int>(
            groupValue: question.correctoptionindex,
            onChanged: (value) {
              if (value != null) {
                setState(() => question.correctoptionindex = value);
              }
            },
            child: Column(
              children: question.optionsControllers.asMap().entries.map((entry) {
                final optionIndex = entry.key;
                final controller = entry.value;
                final isCorrect = question.correctoptionindex == optionIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Radio<int>(
                        value: optionIndex,
                        activeColor: AppTheme.primaryColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          decoration: _inputDecoration(
                            hint: "Option ${optionIndex + 1}",
                          ).copyWith(
                            filled: true,
                            fillColor: isCorrect
                                ? AppTheme.primaryColor.withValues(alpha: 0.05)
                                : Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isCorrect
                                    ? AppTheme.primaryColor.withValues(alpha: 0.4)
                                    : AppTheme.borderColor,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter option ${optionIndex + 1}";
                            }
                            return null;
                          },
                        ),
                      ),
                      if (isCorrect) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "Correct",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
