---
name: ticket-writing
description: Rédiger ou relire un ticket du suivi-projet HubEE (issues / work items GitLab) en restant au bon niveau d'altitude — présenter le problème, pas la solution. À utiliser quand on demande de créer, rédiger, reformuler ou relire un ticket/issue, de transformer un constat ou un bug en ticket, ou quand un ticket existant prescrit déjà la solution technique (mélange problème et implémentation).
---

# Rédiger un ticket HubEE

> **Principe directeur** : un ticket s'arrête au **QUOI** + **POURQUOI** + **DANS QUELLES LIMITES**. Jamais le **COMMENT**. Le comment, c'est la planification (skill `plan`), faite par la personne — ou Claude — qui réalise.

Un bon ticket se lit **en couches**, selon ce que le lecteur cherche — la distinction n'est pas *humain vs Claude*, mais *valider l'intention vs planifier la réalisation* :
- **Valider l'intention** (relecteur, métier, lead) : le haut suffit. *Titre → Problème → Résultat → DoD* répondent à « est-ce le bon problème, bien cadré ? » sans lire le détail.
- **Planifier la réalisation** (le réalisateur, humain *ou* Claude) : *Contraintes*, *Périmètre* et *Ce qui est établi* donnent de quoi planifier sans deviner ce qui est négociable. Ce sont les entrées de la skill `plan`, le DoD devenant les critères de succès.

Tout le monde peut tout lire ; la mise en couches sert juste à valider vite sans tout lire. Le ticket ouvre un espace de solutions **borné** (par les contraintes) sans le réduire à un point : choisir le mécanisme reste le travail du réalisateur.

## Le test d'altitude

Pour **chaque phrase** d'un ticket, se demander :

> **« Est-ce que ça borne le problème, ou est-ce que ça choisit une solution ? »**

- Ça borne le problème → ✅ dans le ticket.
- Ça choisit une solution → ❌ dehors. Au mieux, une note **« Pistes »** explicitement non contraignante.

Exemples de phrases qui **choisissent** une solution (à sortir) : un verbe technique dans le titre (`TRUNCATE`, `migrer vers`, `ajouter un index`), « en une seule transaction », « via un job Sidekiq », « une commande par table ». Tout ça revient à la planif.

## Quand cette skill s'active

- « Crée / rédige / reformule un ticket pour … »
- Transformer un constat, un bug, une demande métier en ticket.
- Relire un ticket existant : repérer et remonter ce qui prescrit la solution.

## Le gabarit

Toutes les sections ne sont pas obligatoires : garder celles qui portent de l'information. Ordre = ordre de lecture pour l'humain.

```markdown
# <Titre : le résultat ou le problème, jamais le mécanisme>

**Problème —** <Le constat, la douleur, l'enjeu. Pourquoi ça vaut un ticket maintenant.>

**Résultat attendu —** <L'état final observable, exprimé en outcome. Pas un moyen.>

**Contraintes & invariants —**
- <Ce que TOUTE solution doit respecter (RGPD, pas de régression prod, traçabilité…).>
- <Un invariant = une borne de l'espace des solutions, pas un choix de solution.>
- *[fait]* <Fait technique qui contraint la solution, ex : « aucune FK entrante ».>

**Périmètre —** Inclus : <…>. Exclu : <… ce qui pourrait être confondu mais ne fait pas partie>.

**Ce qui est établi** *(source + date — contexte non contraignant) —*  *(section optionnelle, voir règles ci-dessous)*
- <Fait vérifié, neutre, qui dé-risque ou cadre.>
- ⚠️ À confirmer : <ce qui reste incertain>.

**DoD —**
- <Critère vérifiable, orienté résultat (« opération tracée », pas « via JobReport »).>

**Dépendances / Liens —** <Tickets liés (#xxx), commentaire shaping, atelier.>
```

### Détails qui font la différence

| Section | À faire | À éviter |
|---|---|---|
| **Titre** | Décrit le résultat (« Éliminer les lignes mortes des `_archive` ») | Le mécanisme (« Purge one-shot TRUNCATE ») |
| **Résultat attendu** | Outcome observable (« les tables ne conservent plus de données > 1 an ») | Un moyen déguisé en objectif (« lancer un TRUNCATE ») |
| **Contraintes** | Bornes que la solution doit respecter | La solution elle-même |
| **DoD** | Vérifiable et orienté résultat | Imposer l'outil (« vérifié via la commande X ») |

## L'investigation : où la mettre

L'analyse déjà faite (preuves, lecture de code, volumétrie) a de la valeur : elle évite que le réalisateur — ou Claude — refasse le travail. Mais elle doit rester du **contexte**, pas une consigne. Deux règles :

1. **Énoncer des faits neutres et sourcés, pas des justifications de solution.**
   ✅ « Établi (analyse `hub-api`, 06/2026) : aucun code n'écrit dans ces tables. »
   ❌ « … donc on peut faire un TRUNCATE. » (le premier borne le problème ; le second choisit à la place du réalisateur)
2. **Un fait n'entre dans le ticket que s'il change les contraintes ou la faisabilité.** Sinon, c'est du *shaping* → commentaire « Contexte / Historique » du ticket (pour ne pas alourdir la lecture rapide), pas le corps.

## Exemple avant / après

**Avant** — la section « À faire » est un plan quasi pur (presque chaque ligne choisit une solution) :

> **[Purge] Purge totale des cases CLOSED > 1 an**
>
> **À faire —** Factoriser le module garde-fous en *concern réutilisable* · activer la règle dans la config par process · *(requête SQL de volumétrie)* · **re-vérification `status = CLOSED` sur la primaire dans la même transaction que le `DELETE`** · cascade via le service de purge · déploiement progressif 3 phases, lock `purge:cases_closed`, Hyperping dédié · specs RSpec.
>
> **DoD —** Module garde-fous factorisé et utilisé par les deux purges.

**Après** — même besoin, mais borné au problème :

> **Purger les télédossiers clos depuis plus d'un an (purge totale RGPD)**
>
> **Problème —** Obligation RGPD niveau 2 : un télédossier doit être entièrement supprimé 1 an après son passage à `CLOSED`. Aujourd'hui ces dossiers clos depuis > 1 an subsistent (DB **et** S3). *Priorité demandée (Laetitia, 21/05).*
>
> **Résultat attendu —** Plus aucune donnée rattachée à un télédossier `CLOSED` depuis > 1 an ne subsiste — métadonnées, cases, events, messages usager, PJ, notifications, applicant orphelin — ni en DB ni en S3.
>
> **Contraintes & invariants —**
> - Suppression conforme RGPD niveau 2 : *rien* ne doit subsister (DB + S3).
> - **Ne jamais purger un dossier qui n'est plus `CLOSED` au moment de la suppression** (un case peut être rouvert entre la sélection et la purge).
> - Opération tracée, supervisée, avec garde-fous (pas de blocage prod).
>
> **Périmètre —** Inclus : cases `CLOSED` > 1 an, tous `process_code`. Exclu : purge partielle (niveau 1), cases non clos.
>
> **Ce qui est établi** *(— contexte) —* une purge totale (> X années) existe déjà avec son module de garde-fous → réutilisable. ⚠️ Volumétrie à calibrer par `process_code` avant lancement.
>
> **DoD —** aucun télédossier `CLOSED` > 1 an ne subsiste (DB + S3) · purge récurrente active · supervision en place.

Le geste à reproduire : « re-vérification dans la même transaction que le `DELETE` » est une *solution* ; l'**invariant** derrière — « ne jamais purger un dossier qui n'est plus `CLOSED` » — reste, lui, dans le ticket. Pour chaque détail technique, remonter à la contrainte qu'il protège : garder la borne, lâcher le mécanisme.

## Erreurs courantes

| Erreur | Correction |
|---|---|
| Le titre nomme le mécanisme | Le titre nomme le résultat ou le problème |
| « Objectif : faire X » où X est un moyen | Reformuler en état final observable |
| L'investigation justifie une solution | La reformuler en fait neutre + sourcé ; sortir la conclusion-solution |
| DoD impose un outil/une commande | DoD vérifiable mais orienté résultat |
| Shaping/historique long dans le corps | Le déplacer en commentaire « Contexte / Historique » |
| Pas de contraintes → Claude doit deviner ce qui est négociable | Expliciter les invariants : c'est ce qui rend la planif possible |

## Articulation avec les autres skills

- **`gitlab`** : pour lire un ticket existant à reformuler, ou préparer la commande d'écriture (médiation humaine).
- **`plan`** : le ticket est l'entrée de la planif. Si en rédigeant tu te surprends à écrire le COMMENT, c'est que tu fais déjà un plan → arrête-toi, le COMMENT ira dans la skill `plan`.
