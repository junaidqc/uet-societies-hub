// ============================================================================
// Model: poll_model.dart & task_model.dart
// Description: Structured payload models for Group Polls and Tasks (FR-29, FR-30)
// ============================================================================

class PollModel {
  final String question;
  final List<String> options;
  /// Mapping of userId -> optionIndex
  final Map<String, int> votes;

  const PollModel({
    required this.question,
    required this.options,
    this.votes = const {},
  });

  factory PollModel.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'] as List<dynamic>? ?? [];
    final rawVotes = map['votes'] as Map<String, dynamic>? ?? {};

    return PollModel(
      question: map['question'] as String? ?? 'Group Poll',
      options: rawOptions.map((e) => e.toString()).toList(),
      votes: rawVotes.map((k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'votes': votes,
    };
  }

  int get totalVotes => votes.length;

  int votesForOption(int index) {
    return votes.values.where((v) => v == index).length;
  }

  double votePercentage(int index) {
    if (totalVotes == 0) return 0.0;
    return votesForOption(index) / totalVotes;
  }
}

class TaskModel {
  final String title;
  final String? description;
  final String? assignedTo;
  final String? assignedToName;
  final DateTime? dueDate;
  final bool isCompleted;

  const TaskModel({
    required this.title,
    this.description,
    this.assignedTo,
    this.assignedToName,
    this.dueDate,
    this.isCompleted = false,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      title: map['title'] as String? ?? 'Untitled Task',
      description: map['description'] as String?,
      assignedTo: map['assigned_to'] as String?,
      assignedToName: map['assigned_to_name'] as String?,
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'] as String) : null,
      isCompleted: map['is_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
      'due_date': dueDate?.toIso8601String(),
      'is_completed': isCompleted,
    };
  }
}
