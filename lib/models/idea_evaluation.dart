import 'json_utils.dart';

class IdeaEvaluation {
  final String idea;
  final int originality;
  final int feasibility;
  final int cost;
  final int effort;
  final int impact;
  final String verdict;
  final String pitch;
  final List<String> strengths;
  final List<String> risks;
  final List<String> nextSteps;

  IdeaEvaluation({
    required this.idea,
    this.originality = 0,
    this.feasibility = 0,
    this.cost = 0,
    this.effort = 0,
    this.impact = 0,
    this.verdict = '',
    this.pitch = '',
    List<String>? strengths,
    List<String>? risks,
    List<String>? nextSteps,
  })  : strengths = strengths ?? [],
        risks = risks ?? [],
        nextSteps = nextSteps ?? [];

  int get overall {
    if (originality <= 0 && feasibility <= 0 && impact <= 0) return 0;
    return ((originality + feasibility + impact) / 3).round();
  }

  String get verdictLabel => verdict.isEmpty ? 'En attente de verdict' : verdict;

  Map<String, dynamic> toJson() => {
        'idea': idea,
        'originality': originality,
        'feasibility': feasibility,
        'cost': cost,
        'effort': effort,
        'impact': impact,
        'verdict': verdict,
        'pitch': pitch,
        'strengths': strengths,
        'risks': risks,
        'nextSteps': nextSteps,
      };

  factory IdeaEvaluation.fromJson(Map<String, dynamic> json) => IdeaEvaluation(
        idea: jsonString(json['idea']),
        originality: jsonInt(json['originality'], 0, min: 0, max: 100),
        feasibility: jsonInt(json['feasibility'], 0, min: 0, max: 100),
        cost: jsonInt(json['cost'], 0, min: 0, max: 100),
        effort: jsonInt(json['effort'], 0, min: 0, max: 100),
        impact: jsonInt(json['impact'], 0, min: 0, max: 100),
        verdict: jsonString(json['verdict']),
        pitch: jsonString(json['pitch']),
        strengths: jsonStringList(json['strengths']),
        risks: jsonStringList(json['risks']),
        nextSteps: jsonStringList(json['nextSteps']),
      );
}