import 'backlog_idea.dart';
import 'chat_turn.dart';
import 'invention_project.dart';
import 'journal_entry.dart';
import 'spark.dart';

class AppData {
  static const int schemaVersion = 1;

  final List<InventionProject> projects;
  final List<BacklogIdea> backlog;
  final List<JournalEntry> journal;
  final List<Spark> sparks;
  final List<ChatTurn> chats;

  AppData({
    List<InventionProject>? projects,
    List<BacklogIdea>? backlog,
    List<JournalEntry>? journal,
    List<Spark>? sparks,
    List<ChatTurn>? chats,
  })  : projects = projects ?? [],
        backlog = backlog ?? [],
        journal = journal ?? [],
        sparks = sparks ?? [],
        chats = chats ?? [];

  int get activeProjects => projects
      .where((p) =>
          p.status == ProjectStatus.idea ||
          p.status == ProjectStatus.plan ||
          p.status == ProjectStatus.building)
      .length;

  int get builtProjects =>
      projects.where((p) => p.status == ProjectStatus.built).length;

  InventionProject? projectById(String? id) {
    if (id == null) return null;
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  AppData copyWith({
    List<InventionProject>? projects,
    List<BacklogIdea>? backlog,
    List<JournalEntry>? journal,
    List<Spark>? sparks,
    List<ChatTurn>? chats,
  }) =>
      AppData(
        projects: projects ?? this.projects,
        backlog: backlog ?? this.backlog,
        journal: journal ?? this.journal,
        sparks: sparks ?? this.sparks,
        chats: chats ?? this.chats,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'projects': projects.map((p) => p.toJson()).toList(),
        'backlog': backlog.map((b) => b.toJson()).toList(),
        'journal': journal.map((j) => j.toJson()).toList(),
        'sparks': sparks.map((s) => s.toJson()).toList(),
        'chats': chats.map((c) => c.toJson()).toList(),
      };

  factory AppData.fromJson(Map<String, dynamic> json) => AppData(
        projects: (json['projects'] as List?)
                ?.map((e) => InventionProject.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            [],
        backlog: (json['backlog'] as List?)
                ?.map((e) => BacklogIdea.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            [],
        journal: (json['journal'] as List?)
                ?.map((e) => JournalEntry.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            [],
        sparks: (json['sparks'] as List?)
                ?.map((e) => Spark.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            [],
        chats: (json['chats'] as List?)
                ?.map((e) => ChatTurn.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            [],
      );
}