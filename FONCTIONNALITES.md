# Fonctionnalités — NabuInvent AI

## Moteur d'IA double

- **Mode local (hors ligne, par défaut)** : un moteur embarqué génère des réponses
  structurées (inventions, plans, évaluations, étincelles, notes de journal) sans
  aucune connexion et sans envoyer la moindre donnée.
- **Mode cloud (OpenAI-compatible)** : branchez n'importe quel service compatible
  (OpenAI, OpenRouter, Mistral, Groq, Perplexity, Claude, Gemini…) via URL de base + clé API + modèle.
  Préréglages fournis. Test de connexion intégré.
- Les deux modes partagent le même contrat de réponse : chaque configuration est un
  cas d'usage réel et fonctionnel.

## Étincelles (générateur d'idées)

- Génère une invention inattendue à partir de thèmes aléatoires
  (ex. : *kg hydraulique* + *sieste* = « le coussin aubergiste qui agit comme une
  bouée de sauvetage »).
- Quota gratuit : **12 étincelles par jour** en mode local (réinitialisé chaque jour).
- Vocation « défie-moi » pour pousser la créativité plus loin.
- **Coffre à étincelles** : chaque étincelle peut être conservée, puis transformée
  en fiche projet complète en un geste.

## Studio (chat)

- Dialogue naturel en français avec l'assistant Nabu.
- Le Studio comprend les demandes de type :
  - *invent* — « Invente-moi un objet pour… »
  - *idea* — « Donne-moi une idée pour… »
  - *plan* — « Élabore le plan de construction de… »
  - *evaluate* — « Évalue cette idée / ce projet »
  - *name* — « Comment nommer une invention qui… ? »
  - *journal* — « Récapitule ce que je fais avec mon projet… »
- Épinglage d'un **projet actif** : les demandes concernent alors ce projet,
  et les réponses mettent la fiche à jour automatiquement.
- Suggestions rapides en un appui.
- Une demande de plan ouvre directement le grand plan du projet actif.

## Projets

- Fiches projets créées automatiquement par l'IA (titre, contexte, mécanisme,
  matériaux, forces/faiblesses, astuces, journal).
- Création manuelle, recherche, filtres par statut.
- Écran de détail complet : infos, forces/faiblesses, astuces, journal intégré.
- **Plan de construction** : liste d'étapes réordonnable, ajout/suppression,
  cases à cocher pour suivre l'avancement (barre de progression).
- Supprimer / dupliquer un projet.

## Réserve d'idées (backlog)

- Capturer rapidement une idée brute (titre, note, tags).
- Transformer une idée en fiche projet complète (avec ou sans évaluation IA).
- Archiver / désarchiver / supprimer, trier, filtrer par tags.

## Journal de bord

- Journal par projet et journal global consultable.
- L'IA peut résumer l'avancée à la demande (mode local), lecture seule.
- Statistiques simples (nombre d'entrées, dernier jour noté).

## Personnalisation

- Thème clair / sombre, choix de la **couleur d'accent** (10 couleurs).
- Mode d'IA configurable, préréglages cloud, test de connexion.

## Données & sauvegarde

- Persistance locale automatique (JSON dans le dossier de l'application),
  écriture atomique avec copie de secours `.bak`.
- **Exporter** la sauvegarde dans un fichier → le partager (email, WhatsApp, cloud…).
- **Importer** une sauvegarde (remplace les données actuelles).
- **Réinitialiser** toutes les données.
- Aucun compte, aucune télémétrie, aucune donnée personnelle collectée.

## Tests & qualité

- 30 tests unitaires couvrant le moteur local (invention, plan, évaluation,
  étincelle, journal, détection d'intention), le parsing des réponses cloud,
  l'application des réponses aux projets et la persistance sur disque.
- Analyse statique Flutter : **zéro problème**.