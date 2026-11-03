# Fonctionnalités — NabuInvent AI

## Atelier d'invention (1.1)

- **Concepts** : une idée exprimée naturellement (« un canard et un héron en boîtes de
  conserve ») donne jusqu'à trois variantes réellement différentes **par objet** : style,
  matériaux, dimensions indicatives, difficulté, temps, budget, avantages, contraintes.
  Le concept choisi devient un projet.
- **Inventeur autonome** : à partir des ressources listées, idées classées par faisabilité,
  avec l'explication de chaque choix.
- **Photo des matériaux** (cloud multimodal) : reconnaissance des objets visibles,
  consentement avant envoi, correction, quantités et dimensions saisies par l'utilisateur.
- **Conception technique** : fiche, nomenclature cotée en mm avec la **provenance** de chaque
  donnée (mesure utilisateur, hypothèse IA, calculé, inconnu) ; calculs déterministes testés
  (quantités, longueurs, surfaces, volumes, plan de découpe et chutes, budget) ; vues face,
  profil, dessus, éclatée, assemblage et plan de découpe dessinés à partir des cotes ; état du
  plan calculé (incomplet / indicatif / cotes vérifiées).
- **Studio visuel** : aperçus artistiques via un vrai service d'images (6 styles),
  modifications en langage naturel, versions conservées ; désactivé s'il n'est pas configuré.
- **Mémoire du projet** : versions restaurables avant chaque modification par l'IA,
  contraintes mémorisées, compréhension de « le deuxième me plaît ».
- **On le fabrique !** : fabrication guidée étape par étape, progression sauvegardée, aide
  pédagogique (plus simplement, sans cet outil, autre méthode, pourquoi).
- **Sécurité** : contrôles déterministes (bords coupants, récipients douteux, corrosion,
  stabilité, électricité, chimie, soudure…), validation professionnelle signalée.
- **Exports** : PDF, PNG, JSON structuré, ZIP ; enregistrement via le sélecteur Android sans
  permission de stockage, ou partage.
- **Réponses lisibles** : plus jamais de JSON brut (réparation des réponses tronquées), fiches
  repliables, copie, sélection ; défilement libre et bouton « Dernier message » ; annulation
  d'une demande en cours ; mode technique pour voir le JSON d'origine (clés masquées).

## Moteur d'IA double

- **Mode local (hors ligne, par défaut)** : un moteur embarqué génère des réponses
  structurées (inventions, plans, évaluations, étincelles, notes de journal) sans
  aucune connexion et sans envoyer la moindre donnée.
- **Mode cloud (OpenAI-compatible)** : branchez n'importe quel service compatible
  (OpenAI, OpenRouter, Mistral, Groq, Perplexity, Claude, Gemini…) via URL de base + clé API + modèle.
  Préréglages fournis. Test de connexion intégré.
- Les deux modes partagent le même contrat de réponse : chaque configuration est un
  cas d'usage réel et fonctionnel.

## Étincelles (générateur d'idées, dans l'Atelier)

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

- 84 tests automatisés : moteur local, détection d'intention, parsing tolérant, rendu et
  défilement du Studio (réponses de 5 000 à 50 000 caractères), concepts, photo (HTTP simulé),
  calculs techniques, plans, sécurité, versions, images, exports PDF/PNG/ZIP, annulation,
  persistance. Détail dans `RAPPORT_TESTS.md`.
- Analyse statique Flutter : **zéro problème**.