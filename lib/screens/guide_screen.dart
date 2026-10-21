import 'package:flutter/material.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const intro = Color(0xFF6B7280);

    Widget section(String title, IconData icon, List<Widget> children) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
    }

    Widget step(int n, String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text('$n.',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary)),
            ),
            Expanded(
              child: Text(text, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      );
    }

    Widget tip(IconData icon, String text) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: const Color(0xFF2E7D32))),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mode d\'emploi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          Text(
            'NabuInvent AI fonctionne entièrement hors ligne par défaut : '
            'tu n\'as besoin d\'aucune configuration pour commencer.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: intro, height: 1.4),
          ),
          const SizedBox(height: 14),
          section('1. Trouver une invention', Icons.lightbulb_outline, [
            step(1, 'Va dans le Studio (onglet 💬).'),
            step(2, 'Écris une phrase naturelle, par exemple : « Invente-moi un '
                'objet pour ranger mon garage ».'),
            step(3, 'Nabu répond avec une fiche projet complète. Appuie sur '
                '« Ouvrir le projet » pour la détailler.'),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 8),
            const Text('Exemples de demandes dans le Studio :',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('• « Donne-moi une idée pour le jardin »'),
                  Text('• « Élabore le plan de construction de… »'),
                  Text('• « Évalue mon idée »'),
                  Text('• « Comment nommer une invention qui… ? »'),
                  Text('• « Récapitule ce que je fais sur mon projet »'),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          section('2. Le projet actif', Icons.push_pin_outlined, [
            Text(
              'Dans le Studio, choisis un projet dans la liste « Projet actif ». '
              'Toutes tes demandes lui seront automatiquement reliées : l\'IA '
              'nomme, évalue et planifie pour ce projet, et met sa fiche à jour '
              'tout seul.',
              style: theme.textTheme.bodyMedium,
            ),
          ]),
          const SizedBox(height: 12),
          section('3. Étincelles (idées surprises)', Icons.auto_awesome, [
            step(1, 'Onglet Étincelles (✨) → « Générer une étincelle ».'),
            step(2, 'Une invention inattendue apparaît (fleur + indice + vocation).'),
            step(3, '« Défi-moi ! » pour une nouvelle variation.'),
            step(4, '« Garder » pour la mettre dans le Coffre.'),
            step(5, 'Dans le Coffre, « Transformer en projet » : la fiche est créée.'),
            tip(Icons.info_outline,
                'En mode local, le quota est de 12 étincelles par jour. En mode '
                'cloud, pas de limite.'),
          ]),
          const SizedBox(height: 12),
          section('4. Plans de construction', Icons.checklist, [
            step(1, 'Depuis une fiche projet → « Élaborer le plan ».'),
            step(2, 'Nabu construit un plan étape par étape.'),
            step(3, 'Onglet « Plan » : coche chaque étape réalisée.'),
            step(4, 'Utilise « + » et la corbeille pour adapter les étapes.'),
          ]),
          const SizedBox(height: 12),
          section('5. Réserve d\'idées (backlog)', Icons.bookmark_add_outlined, [
            step(1, 'L\'onglet 📋 capture une idée brute en 2 secondes (titre, note, tags).'),
            step(2, 'Glisse l\'idée pour l\'archiver, ou « Transformer » pour la '
                'promouvoir en fiche projet complète.'),
          ]),
          const SizedBox(height: 12),
          section('6. Journal de bord', Icons.menu_book_outlined, [
            Text(
              'Dans chaque projet, note tes avancées du jour. Demande au Studio : '
              '« Récapitule ce que j\'ai fait sur mon projet » pour une synthèse. '
              'L\'Accueil te donne un aperçu du journal récent.',
              style: theme.textTheme.bodyMedium,
            ),
          ]),
          const SizedBox(height: 12),
          section('7. Mode cloud (optionnel)', Icons.cloud_outlined, [
            step(1, 'Réglages → « Mode cloud ».'),
            step(2, 'Choisis un fournisseur prédéfini (OpenAI, OpenRouter, Mistral, '
                'Groq, Perplexity, Claude, Gemini…).'),
            step(3, 'Colle ta clé API et vérifie le modèle.'),
            step(4, 'Appuie sur « Tester la connexion » avant de discuter.'),
            tip(Icons.lock_outline,
                'La clé API n\'est stockée que sur ton appareil, jamais envoyée '
                'ailleurs qu\'au fournisseur choisi.'),
            tip(Icons.favorite_outline,
                'En mode local, tout reste confidentiel : aucune donnée ne quitte '
                'ton téléphone.'),
          ]),
          const SizedBox(height: 12),
          section('8. Sauvegarder', Icons.save_outlined, [
            Text(
              'Réglages → Données : exporte régulièrement une sauvegarde (JSON) et '
              'partage-la avec toi-même (email, cloud…). Pour retrouver tes données '
              'plus tard ou sur un autre appareil, importe ce fichier.',
              style: theme.textTheme.bodyMedium,
            ),
          ]),
        ],
      ),
    );
  }
}