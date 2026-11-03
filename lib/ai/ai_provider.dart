import 'dart:async';
import 'dart:typed_data';

import '../models/material_analysis.dart';
import 'ai_response.dart';

abstract class AiProvider {
  String get name;

  bool get isCloud;

  bool get isConfigured;

  Future<NabuAiResponse> respond({
    required String userText,
    List<AiTurn> history = const [],
    String? projectContext,
  });
}

/// Fournisseur capable d'analyser une image (modèle multimodal). Le moteur
/// local ne l'implémente pas : l'analyse de photo n'est jamais simulée.
abstract class VisionProvider {
  Future<MaterialAnalysis> analyzeMaterials({
    required Uint8List imageBytes,
    required String mimeType,
    String note = '',
  });
}

/// Message d'erreur lisible pour une erreur d'appel à un fournisseur IA.
String friendlyAiError(Object e) {
  final text = e.toString();
  if (e is TimeoutException) {
    return 'Le fournisseur n\'a pas répondu à temps. Vérifie ta connexion et réessaie.';
  }
  if (RegExp(r'SocketException|Failed host lookup|Connection (refused|reset)|Network is unreachable')
      .hasMatch(text)) {
    return 'Pas de connexion Internet : cette fonction a besoin du réseau.';
  }
  return text.replaceFirst('Exception: ', '');
}

class AiService {
  final AiProvider provider;

  const AiService({required this.provider});

  String get providerName => provider.name;

  bool get isConfigured => provider.isConfigured;

  bool get isCloud => provider.isCloud;

  Future<NabuAiResponse> ask({
    required String userText,
    List<AiTurn> history = const [],
    String? projectContext,
  }) async {
    if (!provider.isConfigured) {
      return NabuAiResponse(
        provider: provider.name,
        message:
            'Le fournisseur IA « ${provider.name} » n\'est pas configuré. '
            'Ouvre Réglages → Assistant IA pour ajouter ta clé API, ou bascule '
            'sur « Atelier local » pour inventer sans connexion.',
        success: false,
        error: 'provider_not_configured',
      );
    }
    try {
      return await provider.respond(
        userText: userText,
        history: history,
        projectContext: projectContext,
      );
    } catch (e) {
      return NabuAiResponse(
        provider: provider.name,
        message:
            'Erreur de contact avec « ${provider.name} » : $e. '
            'Vérifie la connexion, ta clé API et le modèle, puis réessaie.',
        success: false,
        error: e.toString(),
      );
    }
  }
}