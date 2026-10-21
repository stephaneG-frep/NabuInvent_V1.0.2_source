# Guide de l'utilisateur — NabuInvent AI

## 1. Premier démarrage

Au premier lancement, un écran de bienvenue présente les onglets. Appuyez sur
« Découvrir NabuInvent » pour commencer.

L'application est **prête à l'emploi sans aucune configuration** : elle fonctionne
hors ligne grâce au moteur local.

## 2. Les 5 onglets

| Onglet | Icône | Rôle |
|---|---|---|
| Accueil | 🏠 | Aperçu : dernière étincelle, projets récents, journal, statistiques |
| Projets | 📁 | Toutes vos fiches inventions, filtres, recherche |
| Studio | 💬 | Chat avec l'assistant Nabu |
| Étincelles | ✨ | Générateur d'idées + coffre |
| Réserve d'idées | 📋 | Idées en attente = futur catalogue |

Les Réglages (⚙️) sont accessibles depuis l'Accueil ou l'icône en haut du Studio.

## 3. Trouver une invention (Studio)

Allez dans **Studio** et écrivez une phrase naturelle :

- *« Invente-moi un objet pour faciliter le rangement de mon garage »*
- *« Donne-moi une bonne idée d'invention portable »*
- *« Évalue mon idée »* (si un projet actif est épinglé)

Après quelques secondes, Nabu répond avec une fiche complète. Appuyez sur
**Ouvrir le projet** dans la réponse pour la voir en détail.

### Épinglez un projet actif
Dans le Studio, choisissez un projet dans la liste déroulante « Projet actif ».
Vos demandes lui seront automatiquement liées (nommer, plan, évaluer, journal).

### Suggestions rapides
Appuyez sur une pastille au-dessus du champ pour envoyer la demande en un geste.

## 4. Étincelles (idées surprises)

1. Onglet **Étincelles** → appuyez sur **Générer une étincelle**.
2. L'idée apparaît avec sa « fleur » (invention), un indice et une vocation.
3. **Defi-moi** : demandez une nouvelle variation.
4. **Garder** : elle entre dans le Coffre.
5. Dans le Coffre, **Transformer en projet** : la fiche est créée automatiquement.

> En mode local, le quota est de **12 étincelles par jour** (compteur visible).
> En mode cloud, pas de limite.

## 5. Plans de construction

- Depuis une **fiche projet** → **Élaborer le plan** (demande IA) : Nabu construit
  un plan étape par étape.
- Onglet **Plan** de la fiche : cochez les étapes réalisées !
- Ajouter / retirer des étapes : bouton **+** et icône corbeille sur chaque étape.
- La barre de progression indique l'avancement.

## 6. Réserve d'idées (backlog)

- **+** pour capturer une idée en quelques secondes (titre = seul champ obligatoire,
  note et tags facultatifs).
- Geste de balayage (ou menu) : **Archiver**.
- **Transformer** pour promouvoir l'idée en fiche projet — choisissez éventuellement
  *« avec évaluation IA »*.
- Basculer sur **Archivées** pour revoir ce qui est rangé, ou supprimer.

## 7. Journal de bord

- Dans un projet, onglet ou bouton **Journal** : notez vos avancées du jour.
- **Accueil** donne une vue du journal récent.
- Demandez au Studio : *« Récapitule ce que j'ai fait sur mon projet »* pour que
  l'IA fasse une synthèse (mode local).

## 8. Modes d'IA et réglages

Ouvrez **Réglages** :

1. **Moteur d'IA** : *Local (hors ligne)* par défaut, ou *Cloud (OpenAI-compatible)*.
2. En mode Cloud, choisissez un **préréglage** (OpenAI, OpenRouter, Mistral, Groq,
   Perplexity, Claude, Gemini) puis renseignez **URL de base**, **Clé API** et **modèle**.
3. Appuyez sur **Tester la connexion** pour valider avant de discuter.

> 🔒 La clé API n'est stockée que sur votre appareil, chiffrée par le système
> (Keystore Android), et n'est pas incluse dans les sauvegardes Android.
> L'URL de base doit commencer par `https://`.

- **Apparence** : thème clair/sombre, couleur d'accent (10 choix).

## 9. Sauvegarder / restaurer vos données

- **Exporter** : l'application génère un fichier de sauvegarde → partagez-le
  (email, cloud…). Rangez-le précieusement.
- **Importer** : sélectionnez une sauvegarde ; après confirmation, vos données
  actuelles sont **remplacées** par celles du fichier (exportez d'abord si besoin).
- Les sauvegardes Android automatiques sont désactivées (pour protéger la clé
  API) : pensez à **exporter** avant de changer de téléphone.
- **Réinitialiser** : efface tout et revient à zéro.

## 10. Dépannage

| Problème | Solution |
|---|---|
| Le Studio ne répond pas | Vérifier le mode (Réglages). En mode Cloud, tester la connexion ; vérifier URL/clé/modèle. |
| Quota d'étincelles atteint | Attendre demain, ou passer en mode Cloud. |
| L'APK ne s'installe pas | Autoriser l'installation d'apps inconnues, réessayer. |
| Perte de données | Restaurer la dernière sauvegarde exportée. |