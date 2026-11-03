# Journal des modifications — NabuInvent AI

## 1.1.0 (5) — Atelier d'invention

### Corrections Android
- **Réponses JSON brutes** : les réponses tronquées ou abîmées sont réparées et affichées en
  fiches lisibles ; les anciennes réponses brutes déjà enregistrées sont ré-interprétées à
  l'affichage. Limite de réponse portée de 1 800 à 4 096 tokens.
- **Défilement bloqué** : suppression du retour automatique en bas à chaque geste ; défilement
  automatique seulement si l'on est déjà en bas ; bouton « Dernier message ».

### Nouveautés
- Onglet **Atelier** (remplace l'onglet Étincelles, désormais dans l'Atelier) : idée →
  concepts (3 variantes par objet), inventeur autonome à partir des ressources, galerie de
  concepts.
- **Analyse des matériaux par photo** (modèle multimodal, consentement, correction).
- **Conception technique** : fiche, nomenclature cotée avec provenance des données, calculs
  déterministes, plan de découpe, vues techniques, état du plan calculé.
- **Studio visuel** : aperçus via un service `/images/generations`, 6 styles, modifications,
  versions.
- **Mémoire du projet** : versions restaurables, contraintes mémorisées, « le deuxième me plaît ».
- **On le fabrique !** : fabrication guidée avec aide pédagogique.
- **Contrôles de sécurité** déterministes et validation professionnelle signalée.
- **Exports** PDF, PNG, JSON, ZIP (sélecteur Android, partage).
- **Annulation** d'une demande à l'IA en cours ; une seule demande à la fois depuis l'Atelier.
- Réglages : génération d'images (clé chiffrée), **mode technique** (JSON d'origine, clés
  masquées) ; teintes **Cuivre** (défaut) et **Bronze**.

### Technique
- Dépendances ajoutées : `image_picker`, `pdf`, `archive` ; police DejaVu Sans embarquée
  (PDF).
- Contrat IA étendu (`concepts`, `resources`, `techSheet`, champs d'étape `objective`,
  `dimensions`, `tips`) ; données existantes relues sans perte.
- 84 tests automatisés (34 avant).

## 1.0.3 (4)
- Signature release (`android/key.properties`), `.gitignore`, nettoyage de l'historique git.

## 1.0.2 (3)
- Audit et corrections : perte de données (écriture atomique, `.bak`), projets écrasés,
  étapes cloud cochées ensemble, détection d'intention, clé API chiffrée, messages d'erreur
  des fournisseurs, paramètres refusés (`temperature`), réglages bloqués en release (R8).
