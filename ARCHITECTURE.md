# Architecture du GPP - proposition v3

- **Statut** : proposition, soumise à la validation du GIP-CAD.
- **Version** : v3 du 18/11/2026 ; elle achève l'ébauche du 10/02/2026, qu'elle remplace.
- **Périmètre** : le Gestionnaire des Processus Projets (GPP) de ce dépôt et ses échanges avec la plateforme publique demarche.numerique.gouv.fr.

## Synthèse

Les porteurs de projet déposent leur dossier de candidature sur la plateforme publique demarche.numerique.gouv.fr. Le GPP, instance privée du GIP-CAD dérivée du logiciel libre démarche numérique (anciennement demarches-simplifiees.fr), va chercher ces dossiers par l'API GraphQL de la plateforme et crée pour chacun un dossier local, que les agents du GIP-CAD instruisent avec des outils propres : liste de contrôle, notes et pièces jointes par critère, calendrier du CSE (Comité Scientifique et Éthique). Le contenu des dossiers (réponses au formulaire, pièces jointes) reste sur la plateforme publique : le GPP ne recopie que quelques métadonnées de chaque dossier, dont le numéro, l'état et l'identité du demandeur. Entre le GPP et la plateforme, tous les échanges partent du GPP ; la plateforme ne l'appelle jamais.

Cette proposition décrit l'architecture en place et lui ajoute deux chantiers, marqués « cible » : un retour vers la plateforme publique, pour que la prise en charge, les demandes de correction, les messages et la décision parviennent au porteur là où il a déposé son dossier (section 6.5) ; et sept évolutions de la synchronisation, dont cinq corrections d'anomalies (section 6.6). La section 9 fait le point, besoin par besoin, sur ce qui est réalisé et ce qui reste à faire ; la section 10 liste les décisions attendues du GIP-CAD.

## 1. Besoin

La spécification d'entrée du GPP (GIPCAD_sicad_gpp_gestionnaire-processus-projets, v1.0.0 du 05/07/2024) et l'annexe « Module de gestion CSE » de GIPCAD_PORtails_démarches demandent de sortir la gestion des projets du CSE du « mode Excel » :

- gérer le cycle de vie de chaque demande et de chaque projet, internes ou externes au GIP-CAD, avec leur documentation et leurs relances ;
- tenir le calendrier du CSE : une réunion par mois (T0) ; examen des dossiers reçus au plus tard à T0 - 2 semaines ; envoi de l'avis à T0 + 1 semaine et des motivations à T0 + 2 semaines ;
- conserver, pour chaque projet, le dossier de candidature, les noms et les grilles d'analyse des deux rapporteurs, le résultat du vote, l'avis, les motivations et leurs notifications, ainsi que des métadonnées, notamment : identifiant, nom et sigle du projet, porteur, dates précises de dépôt, d'examen, d'avis et de notification, dates de début et de fin, durée de rétention des données ;
- suivre chaque projet une fois par an, et produire chaque année une cartographie des projets déposés ;
- attribuer des identifiants techniques qui assurent la traçabilité de la demande initiale jusqu'aux données injectées dans les environnements cloisonnés.

Les candidatures sont déposées sur la plateforme publique nationale. Elle est administrée indépendamment du GIP-CAD, qui n'y dispose que des droits d'administrateur et d'instructeur sur ses propres démarches.

## 2. Options examinées

| Option | Intérêt | Limite |
|---|---|---|
| A. Instruire directement sur la plateforme publique | Rien à développer ni à héberger ; le moteur d'instruction de la plateforme, tel quel | La plateforme ne se modifie pas : ni liste de contrôle qui conditionne l'acceptation, ni notes par critère, ni calendrier du CSE |
| B. Application de suivi légère, qui interroge l'API de la plateforme | Application réduite, simple à maintenir | Elle ne fait que suivre : l'instruction reste sur la plateforme publique, sans outils propres |
| C. Instance privée dérivée de démarche numérique, synchronisée avec la plateforme | Réutilise le moteur d'instruction de démarche numérique (instructeurs, états, décisions motivées, avis d'experts, annotations privées) et accueille les outils propres | Un fork à maintenir ; deux outils pour les agents, qui lisent le contenu des dossiers sur la plateforme publique |

L'option C est celle que ce dépôt met en œuvre et que cette proposition retient ; le GIP-CAD ne l'a pas encore validée formellement (section 10). Son coût est le fork : le GPP part du commit amont `2a34f8c7b`, aucune évolution amont n'a été fusionnée depuis, et la suppression des pages usager (environ 11 800 lignes) rend chaque fusion coûteuse. Suivre l'amont ou figer une version est aussi une décision du GIP-CAD.

## 3. Vue d'ensemble

```
   Porteur de projet                       Agent du GIP-CAD
          |                                 |            |
          | (1) dépôt          (3) lecture  |            | (4) instruction
          v                    du contenu   |            |
+----------------------------------+        |            |
| Plateforme publique              |<-------+            |
| demarche.numerique.gouv.fr       |                     |
| démarche de candidature          |                     |
| API GraphQL : /api/v2/graphql    |                     |
+----------------------------------+                     |
          ^                                              |
          | HTTPS, à l'initiative du GPP                 |
          | (2) lecture des dossiers                     |
          | (5) décision, messages, corrections (cible)  |
          |                                              v
+--------------------------------------------------------------+
| GPP, instance privée du GIP-CAD                              |
| application web : administration, instruction, CSE           |
| worker delayed_job : synchronisation                         |
| PostgreSQL, Redis, stockage des fichiers                     |
+--------------------------------------------------------------+
```

1. **Dépôt** : le porteur remplit et dépose son dossier sur la plateforme publique ; le GPP n'intervient pas.
2. **Synchronisation** (réalisée) : le GPP lit les dossiers de la démarche publique liée et crée les dossiers locaux (section 6.2).
3. **Lecture du contenu** (réalisée ; lien à corriger) : l'agent lit les réponses et les pièces jointes sur la plateforme publique, avec un compte instructeur de la démarche publique (section 6.3).
4. **Instruction** (réalisée) : l'agent instruit le dossier local dans le GPP (section 6.4).
5. **Retour vers la plateforme publique** (cible) : le GPP y reporte la prise en charge, les demandes de correction, les messages et la décision (section 6.5).

## 4. Composants

- **Plateforme publique** (demarche.numerique.gouv.fr) : dépôt des dossiers, contenu des dossiers, messagerie avec le porteur. Le GIP-CAD y administre ses démarches de candidature et y crée le jeton d'API du GPP.
- **Application web du GPP** : application Rails, fork de démarche numérique. Elle garde les pages d'administration, d'instruction et d'avis d'experts ; les pages usager ont été retirées. Elle ajoute la liaison avec la démarche publique, la synchronisation, la liste de contrôle, les notes par critère et le calendrier du CSE.
- **Worker** : delayed_job (`bin/rake jobs:work`), qui exécute la synchronisation périodique. `RAILS_QUEUE_ADAPTER=delayed_job` doit être positionné dans tout déploiement : sans ce réglage, `config/environments/production.rb` choisit Sidekiq, alors que la synchronisation périodique repose sur delayed_job (`config/initializers/auto_sync_scheduler.rb` lit la table `Delayed::Job`).
- **PostgreSQL** : les données de démarche numérique et les tables du GPP (section 5).
- **Redis et stockage des fichiers** : tels que les déclare `docker-compose.yml` (configuration d'essai, section 8) ; le stockage reçoit notamment les pièces jointes des notes.
- **Compte technique** `system@gipcad.local` : propriétaire des dossiers créés par la synchronisation, avec un mot de passe aléatoire ; personne ne s'en sert pour se connecter.

## 5. Données

### Tables propres au GPP

| Modèle | Contenu | Rôle |
|---|---|---|
| `ProcedureMirror` | URL de l'instance publique, numéro de la démarche publique, fréquence de synchronisation (minutes), date de la dernière synchronisation | Lie une démarche du GPP à une démarche publique ; plusieurs liaisons peuvent coexister. |
| `LinkedDossier` | URL de l'instance, numéro et identifiant GraphQL du dossier public, état public ; civilité, nom et prénom du demandeur ; email du compte qui a déposé le dossier | Lie un dossier local à un dossier public. |
| `ChampNote` | Texte et pièces jointes | Note d'un agent sur un critère de la liste de contrôle. |
| `CseDate` | Date | Date d'une séance du CSE pour une démarche. |

Rien n'empêche aujourd'hui de lier une même démarche publique à deux démarches du GPP (section 6.6, point 3).

### Ce qui reste sur la plateforme publique

Les réponses au formulaire, les pièces jointes du porteur et la messagerie avec lui. Le GPP ne les recopie pas, et cette proposition garde ce principe, qui limite les données personnelles détenues par le GPP ; l'agent les lit sur la plateforme publique (flux 3).

### Données personnelles

« Demandeur » est le terme de la plateforme pour la personne au nom de qui le dossier est déposé ; ce n'est pas toujours le titulaire du compte, car un mandataire peut déposer pour un tiers. Le GPP conserve la civilité, le nom et le prénom du demandeur et l'email du compte qui a déposé le dossier (dans `LinkedDossier`, et le nom et le prénom aussi dans l'identité du dossier local quand la démarche s'adresse à des particuliers), ainsi que les notes et les pièces jointes des agents. Ce traitement relève du registre des traitements du GIP-CAD ; sa durée de conservation est à fixer (section 10).

## 6. Flux

### 6.1 Liaison d'une démarche (réalisée)

Sur la page de gestion d'une démarche du GPP, bloc « Liaison avec la démarche publique », l'administrateur saisit le numéro de la démarche publique et clique « Lier ». L'URL de l'instance est lue dans `PUBLIC_DS_API_URL` à ce moment et conservée dans la liaison (à défaut, `https://www.demarches-simplifiees.fr`, ancienne adresse de la plateforme ; il faut donc renseigner la variable) : changer la variable ensuite ne déplace pas les liaisons existantes. « Délier » supprime la liaison.

### 6.2 Synchronisation descendante (réalisée)

- **Déclenchement** : manuellement, bouton « Synchroniser » du tableau des dossiers ; ou périodiquement, bouton « Synchronisation auto. » de la page de gestion (fréquence en minutes, heures ou jours). `SyncDossiersJob` s'exécute puis se remet en file ; au démarrage de l'application, `auto_sync_scheduler.rb` remet en file les liaisons qui n'ont plus de tâche en attente (section 6.6, point 5).
- **Requête** : `demarche(number:)`, puis pour chaque dossier `id`, `number`, `state`, `usager { email }` et `demandeur { ... on PersonnePhysique { civilite nom prenom } }`, authentifiée par le jeton `PUBLIC_DS_API_TOKEN`, lu à chaque synchronisation. L'API ne renvoie pas les brouillons.
- **Traitement** : un dossier public inconnu (clé : URL de l'instance et numéro du dossier) devient un dossier local « en instruction », créé par le compte technique dans le groupe d'instructeurs par défaut, avec son `LinkedDossier`. Pour un dossier déjà connu, seul l'état public est mis à jour.
- **Sans jeton**, la synchronisation manuelle affiche une alerte et la synchronisation périodique ne fait rien, sans le signaler.

### 6.3 Lecture du contenu (réalisée, lien à corriger)

L'agent ouvre le dossier public depuis le bloc « Dossier lié » de la page du dossier ou depuis le tableau des dossiers. Il lui faut un compte instructeur de la démarche publique.

Le lien pointe aujourd'hui vers `<instance>/dossiers/<numéro du dossier>`. Dans le code de démarche numérique dont part le fork, cette adresse est la page du porteur, ouverte au seul propriétaire du dossier et à ses invités ; la page d'un instructeur est `<instance>/procedures/<numéro de la démarche>/dossiers/<numéro du dossier>`. À vérifier sur la plateforme publique, puis corriger `LinkedDossier#public_dossier_url`.

### 6.4 Instruction (réalisée)

- **Liste de contrôle** : les champs Oui/Non de la démarche du GPP sont les critères de contrôle. « Accepter » reste désactivé tant qu'un critère n'est pas coché « Oui » ; refuser et classer sans suite restent possibles à tout moment.
- **Notes et pièces jointes** par critère (`ChampNote`), en lecture seule une fois le dossier terminé.
- **Tableau des dossiers** : la colonne « Demandeur » affiche l'email du compte qui a déposé le dossier sur la plateforme, mais son tri et son filtre portent sur le propriétaire local, le compte technique, le même pour tous les dossiers ; à corriger.
- **Calendrier du CSE** : l'administrateur choisit les dates des séances (« Calendrier CSE »). La date limite de dépôt est la date du prochain CSE moins 14 jours. Quand le tableau des dossiers est trié par date de dépôt, un séparateur la signale et les dossiers dont la date de dépôt la dépasse sont grisés ; cette date de dépôt est aujourd'hui celle de la première synchronisation (section 6.6, point 2).

### 6.5 Retour vers la plateforme publique (cible)

Aujourd'hui, ce que l'agent fait dans le GPP n'est pas reporté sur la plateforme publique : le porteur n'en voit rien, et pour l'en informer il faut refaire l'opération à la main sur la plateforme. Le GPP reporterait ses actions par les mutations de l'API GraphQL de la plateforme :

| Action dans le GPP | Mutation de l'API publique | Effet pour le porteur |
|---|---|---|
| Prise en charge du dossier (moment à fixer, section 10) | `dossierPasserEnInstruction` | Il ne peut plus modifier son dossier. |
| Demande de complément ou de correction | `dossierEnvoyerMessage`, avec l'argument `correction` | Il reçoit le message ; selon la description de l'API, le dossier repasse alors en construction pour qu'il le corrige. |
| Message | `dossierEnvoyerMessage` | Il reçoit le message. |
| Acceptation, refus, classement sans suite | `dossierAccepter`, `dossierRefuser`, `dossierClasserSansSuite` | Il reçoit la décision et sa motivation, obligatoire pour un refus ou un classement sans suite. |

Conditions de mise en œuvre :

- un jeton d'API avec droit d'écriture, soumis aux restrictions de la section 7 ;
- un compte instructeur de la démarche publique, sous lequel le GPP effectue toutes ces opérations (les mutations exigent son identifiant, `instructeurId`) ;
- une tâche par opération, rejouable : elle vérifie l'état public avant d'agir, journalise l'appel et signale un échec sur le dossier du GPP ;
- le retour des corrections : un dossier corrigé par le porteur reste en principe « en construction » sur la plateforme ; la synchronisation doit le signaler à l'agent (section 6.6, point 6), qui le reprend en instruction ;
- les notifications : la plateforme prévient le porteur selon ses propres règles ; pour les changements d'état, l'argument `disableNotification` permet de couper cet envoi, choix à faire par le GIP-CAD.

Le calendrier du CSE peut s'appuyer sur ce retour : l'avis (T0 + 1 semaine) par un message, les motivations (T0 + 2 semaines) avec la décision motivée. Ce découpage est à valider avec le secrétariat du CSE (section 10).

### 6.6 Synchronisation : corrections et améliorations (cible)

Les cinq premiers points corrigent des anomalies du code actuel ; les deux derniers l'améliorent.

1. **Pagination** : transmettre le curseur de page (`after`). Aujourd'hui, au-delà d'une page de dossiers sur la démarche publique, la synchronisation redemande sans fin la première page. À corriger avant tout usage réel.
2. **Date de dépôt** : lire `dateDepot` et l'enregistrer comme date de dépôt du dossier local. Aujourd'hui, cette date est celle de la première synchronisation, alors que la colonne « Date de dépôt » du tableau et la date limite du CSE la traitent comme la date de dépôt sur la plateforme : un dossier déposé à temps mais synchronisé après la limite apparaît, à tort, hors délai.
3. **Unicité des liaisons** : la migration qui crée `procedure_mirrors` déclare un index unique sur l'URL de l'instance et le numéro de la démarche publique, mais `db/schema.rb` ne le contient pas : une base créée à partir du schéma n'a pas cet index, et ni le modèle ni l'écran de liaison ne contrôlent l'unicité. Une même démarche publique peut alors être liée à deux démarches du GPP, et ses dossiers ne sont créés que dans celle qui se synchronise la première (section 6.2). Rétablir l'index dans le schéma et valider l'unicité dans le modèle.
4. **Compte technique** : si `system@gipcad.local` ne peut pas être créé, la synchronisation attribue aujourd'hui les dossiers au premier utilisateur de la base, un compte qui n'est pas fait pour cela ; elle devrait échouer.
5. **Remise en file au démarrage** : `auto_sync_scheduler.rb` cherche l'identifiant de la démarche comme sous-chaîne de la tâche sérialisée, ce qui peut faire croire qu'une tâche est en attente quand plusieurs liaisons existent ; comparer l'argument de la tâche.
6. **Synchronisation incrémentale** : passer `updatedSince` (date de la dernière synchronisation) pour ne relire que les dossiers modifiés, et signaler à l'agent les dossiers repassés en construction puis corrigés (section 6.5).
7. **Erreurs** : celles de la synchronisation périodique ne sont écrites que dans le journal de l'application ; afficher le résultat de la dernière synchronisation (dossiers créés, mis à jour, en erreur) à côté de sa date, que le GPP affiche déjà.

## 7. Sécurité

- **Échanges avec la plateforme publique** : uniquement sortants, du GPP vers la plateforme, en HTTPS. La plateforme sait appeler une URL propre à chaque démarche quand un dossier change d'état (webhook), mais cela exigerait que le GPP soit joignable depuis Internet : le GPP interroge donc la plateforme.
- **Jeton d'API** : un secret de l'environnement, jamais en base ni dans le dépôt. Il est créé sur le profil du titulaire du compte administrateur de la démarche publique (carte « Jetons d'identification de l'API (token) »), qui le renouvelle. Il doit être limité aux démarches liées, au réseau du GPP et dans le temps : le code de démarche numérique prévoit ces trois restrictions. La synchronisation n'a besoin que de la lecture (le README fait créer un jeton en lecture seule) ; le retour vers la plateforme (section 6.5) demandera l'écriture.
- **Comptes** : administrateurs, instructeurs et experts ont des comptes du GPP, avec les rôles de démarche numérique. Le GPP n'a pas de pages usager ; le compte technique (section 4) est le seul propriétaire des dossiers synchronisés.
- **Données personnelles** : minimisation (section 5) ; jamais de dossier réel dans les jeux d'essai, les tests ou les journaux.

## 8. Exploitation

- **Variables** : `PUBLIC_DS_API_URL`, lue à la liaison ; `PUBLIC_DS_API_TOKEN`, lue à chaque synchronisation ; `RAILS_QUEUE_ADAPTER=delayed_job`, obligatoire.
- **Processus et services** : serveur web, worker delayed_job, PostgreSQL, Redis, stockage des fichiers.
- **Essais** : DOCKER-SETUP.md décrit comment monter côte à côte le GPP et une instance de démarche numérique qui joue la plateforme publique (ports 3002 et 3003), puis dérouler la liaison et la synchronisation. Les fichiers Docker de ce dépôt (`docker-compose.yml`, `docker/`) servent aux essais seulement : leur point d'entrée supprime toutes les tables quand celle des démarches manque.
- **Production** : l'hébergement reste à décider (section 10). À la date de ce document et à notre connaissance, aucun essai n'a été fait sur la plateforme publique réelle.

## 9. Couverture du besoin et état de réalisation

| Besoin ou fonction | Réponse | État |
|---|---|---|
| Dépôt des candidatures | Plateforme publique | Réalisé |
| Liaison et synchronisation des dossiers | `ProcedureMirror`, `SyncDossiersJob` | Réalisé ; corrections en 6.6 |
| Liste de contrôle, notes et pièces jointes | Outils propres du GPP | Réalisé |
| Calendrier du CSE et date limite de dépôt | `CseDate` | Réalisé ; date de dépôt à corriger (6.6, point 2) |
| Lecture du dossier public | Lien depuis le GPP | Lien à vérifier et à corriger (6.3) |
| Prise en charge, messages, corrections et décision vers le porteur | Retour vers la plateforme (6.5) | À construire |
| Avis à T0 + 1 semaine, motivations à T0 + 2 semaines | Message, puis décision motivée (6.5) | À construire |
| Deux rapporteurs et leurs grilles d'analyse | Avis d'experts, fonction héritée de démarche numérique | À évaluer |
| Métadonnées du projet (dates, identifiants, durée de rétention) | Annotations privées de la démarche du GPP, fonction héritée | À évaluer |
| Relances, suivi annuel et cartographie annuelle des projets | - | Hors de cette version |
| Identifiants techniques et traçabilité jusqu'aux environnements cloisonnés | Interface à définir | Hors de cette version |

Le code propre au GPP n'a aujourd'hui aucun test automatisé : chaque évolution de cette proposition doit venir avec ses tests, et les fonctions déjà réalisées en ont besoin aussi.

## 10. Décisions attendues du GIP-CAD

1. **Proposition** : valider l'option C (section 2) et cette proposition.
2. **Fork** : suivre l'amont par des fusions régulières, ou figer une version ; dans les deux cas, désigner qui suit les correctifs de sécurité de démarche numérique.
3. **Retour vers la plateforme publique** (section 6.5) : l'adopter ou non ; désigner le titulaire du compte administrateur de la démarche publique (création et renouvellement du jeton) et le compte instructeur sous lequel le GPP agit ; fixer le moment de la prise en charge (dès la synchronisation, ou à la première action d'un agent), l'usage des notifications et, avec le secrétariat du CSE, le découpage entre l'avis et les motivations.
4. **Hébergement** du GPP.
5. **Données personnelles** : inscrire au registre des traitements, s'il n'y figure pas, le traitement décrit en section 5, et fixer la durée de conservation des données copiées.
6. **Lien avec le SIV** : la spécification du SIV (GIPCAD_sicad_service_ri_venues, §3.8) prévoit d'automatiser l'enrôlement des tenants, les acteurs pour lesquels le service de réception est activé, à partir d'un « module de gestion des projets » incluant les tenants et les projets CSE ; décider si le GPP est ce module.

## 11. Références

- Dans ce dépôt : README.md, DOCKER-SETUP.md, doc/faqs/ (fiches du GPP : présentation générale, administration, instruction).
- Code : `app/models/procedure_mirror.rb`, `app/models/linked_dossier.rb`, `app/models/champ_note.rb`, `app/models/cse_date.rb`, `app/services/public_dossier_sync_service.rb`, `app/jobs/sync_dossiers_job.rb`, `config/initializers/auto_sync_scheduler.rb`.
- Spécifications du GIP-CAD : GIPCAD_sicad_gpp_gestionnaire-processus-projets (v1.0.0, 05/07/2024) ; GIPCAD_PORtails_démarches, annexe « Module de gestion CSE » ; GIPCAD_sicad_service_ri_venues, §3.8.
- API GraphQL de la plateforme publique : https://doc.demarches-simplifiees.fr/api-graphql/introduction-technique (adresse donnée par GIPCAD_PORtails_démarches).
