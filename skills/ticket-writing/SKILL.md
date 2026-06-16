---
name: ticket-writing
description: Rédiger ou relire un ticket du suivi-projet HubEE (issues / work items GitLab) en restant au bon niveau d'altitude — présenter le problème, pas la solution. À utiliser quand on demande de créer, rédiger, reformuler ou relire un ticket/issue, de transformer un constat ou un bug en ticket, ou quand un ticket existant prescrit déjà la solution technique (mélange problème et implémentation).
---

# Rédiger un ticket HubEE

> **Principe directeur** : un ticket s'arrête au **QUOI** + **POURQUOI** + **DANS QUELLES LIMITES**. Jamais le **COMMENT**. Le comment, c'est la planification (skill `plan`), faite par la personne — ou Claude — qui réalise.

Un bon ticket se lit **en couches**, selon ce que le lecteur cherche — la distinction n'est pas *humain vs Claude*, mais *valider l'intention vs planifier la réalisation* :
- **Valider l'intention** (relecteur, métier, lead) : *Titre + Le problème* suffisent — le récit dit la situation, l'outcome visé et le bénéfice, donc « est-ce le bon problème, bien cadré ? » sans lire le détail.
- **Planifier la réalisation** (le réalisateur, humain *ou* Claude) : *Hors périmètre*, *Contraintes* et *Critères d'acceptation* (+ le contexte) donnent de quoi planifier sans deviner ce qui est négociable. Ce sont les entrées de la skill `plan`, les critères d'acceptation devenant les critères de succès.

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

Le ticket s'ouvre sur **Le problème** (un récit court : situation, outcome visé, bénéfice). Suivent des blocs courts et étiquetés — **Hors périmètre**, **Contraintes**, **Critères d'acceptation**, **Contexte** — chacun avec un seul rôle. Garder ce qui porte de l'information.

```markdown
# <Titre : le problème, jamais le résultat ni le mécanisme>

**Le problème —** <Récit court (2-4 phrases) : la situation, qui en souffre, pourquoi
ça vaut un ticket maintenant. Inclure l'outcome visé (l'état final observable, pas un
moyen) et le bénéfice concret. Y glisser l'urgence/échéance s'il y en a une.>

**Hors périmètre —** <Ce qui pourrait être confondu mais ne fait pas partie du ticket.>

**Contraintes & invariants —**
- <Ce que TOUTE solution doit respecter — **uniquement métier / régulatoire** (RGPD, pas de blocage de la production, traçabilité…). Un fait technique n'est pas un invariant : il va dans le contexte.>
- <Un invariant borne sans choisir : « ne jamais supprimer un dossier qui n'est pas `CLOSED` », pas « re-vérifier dans la même transaction ».>

**Critères d'acceptation —**
- <Vérifiable, orienté résultat et métier (« opération tracée », pas « via JobReport »).>
- <Une capacité, pas une exécution complète one-shot : « les dossiers éligibles finissent traités », pas « tout est purgé maintenant ».>

**Contexte —** *(facultatif)* <Faits sourcés non contraignants qui dé-risquent ou cadrent, et pièges connus, ex. « aucune FK entrante vers ces tables ». ⚠️ Marquer ce qui reste à confirmer.>

**Dépendances / Liens —** <Tickets liés (#xxx), commentaire shaping, atelier.>
```

### Détails qui font la différence

| Élément | À faire | À éviter |
|---|---|---|
| **Titre** | Décrit le problème (« La base `_archive` grossit sans limite ») | Le résultat (« Éliminer les lignes mortes des `_archive` ») ou le mécanisme (« Purge one-shot TRUNCATE ») |
| **Le problème** | Récit court : situation + outcome observable (« les tables ne conservent plus de données > 1 an ») + bénéfice (« moins de sollicitations support ») | Un moyen déguisé en objectif (« lancer un TRUNCATE »), ou re-décrire la fonctionnalité au lieu du bénéfice |
| **Contraintes** | Bornes **métier / régulatoires** uniquement | La solution elle-même, ou un invariant technique (→ contexte) |
| **Critères d'acceptation** | Couverture (« les éligibles finissent traités ») **et** sûreté (« rien d'autre n'est touché »), vérifiables | N'exiger qu'une face : oublier la couverture (une purge qui ne fait rien « passe »), ou imposer le one-shot |

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

> **Des télédossiers clos depuis plus d'un an subsistent (non-conformité RGPD niveau 2)**
>
> **Le problème —** Le RGPD niveau 2 impose de supprimer entièrement un télédossier 1 an après sa clôture. Aujourd'hui ce n'est pas fait : des dossiers clos depuis plus d'un an restent en base et sur S3. On veut qu'ils disparaissent réellement — données et pièces — pour lever le risque juridique et cesser de stocker ce qu'on aurait dû effacer. *Prioritaire (demande Laetitia, 21/05).*
>
> **Hors périmètre —** La purge partielle (niveau 1) ; les dossiers non clos.
>
> **Contraintes & invariants —**
> - Conformité RGPD niveau 2 : *rien* ne doit subsister (DB + S3).
> - **Ne jamais supprimer un dossier qui n'est pas `CLOSED` au moment de la suppression.**
> - Opération tracée, supervisée, sans blocage de la production.
>
> **Critères d'acceptation —**
> - Tout dossier éligible (`CLOSED` > 1 an) et ses pièces *finissent* supprimés par la purge récurrente — aucun éligible ignoré.
> - Tout dossier supprimé était bien `CLOSED` > 1 an (pas de suppression à tort).
> - Suppression effective DB + S3.
> - Le volume traité par passage est paramétrable par `process_code`.
> - Purge récurrente active et supervisée.
>
> **Contexte —** Une purge totale (> X années) existe déjà avec ses garde-fous. ⚠️ Volumétrie réelle à confirmer par `process_code`.

Le geste à reproduire : « re-vérification dans la même transaction que le `DELETE` » est une *solution* ; l'**invariant** derrière — « ne jamais supprimer un dossier qui n'est pas `CLOSED` » — reste, lui, dans le ticket. Pour chaque détail technique, remonter à la contrainte qu'il protège : garder la borne, lâcher le mécanisme.

> ⚠️ Le piège du one-shot : « plus aucun télédossier `CLOSED` > 1 an ne subsiste » (au présent) imposerait de vider tout le stock d'un coup. La couverture reste exigée, mais **au futur** : « les éligibles *finissent* supprimés par la purge récurrente — aucun ignoré ». On garantit que rien n'est oublié sans imposer le rythme (d'un coup ou par lots sur plusieurs mois — choix de réalisation).

## Erreurs courantes

| Erreur | Correction |
|---|---|
| Le titre nomme le résultat ou le mécanisme | Le titre nomme le problème |
| « Objectif : faire X » où X est un moyen | Reformuler en état final observable |
| L'investigation justifie une solution | La reformuler en fait neutre + sourcé ; sortir la conclusion-solution |
| Un invariant technique présenté comme intouchable | Le passer en fait sourcé dans la note de contexte (souvent négociable selon l'urgence) |
| Critère d'acceptation imposant un outil/une commande | Critère vérifiable mais orienté résultat |
| Critère exigeant une exécution complète (« tout est purgé ») | Porter sur ce qui est produit, pas sur l'épuisement du stock (par lots possible) |
| Shaping/historique long dans le corps | Le déplacer en commentaire « Contexte / Historique » |
| Inventer des contraintes pour remplir la section | S'il n'y a pas de contrainte métier, c'est légitime de ne pas en mettre ; n'expliciter que les invariants réels |

## Articulation avec les autres skills

- **`gitlab`** : pour lire un ticket existant à reformuler, ou préparer la commande d'écriture (médiation humaine).
- **`plan`** : le ticket est l'entrée de la planif. Si en rédigeant tu te surprends à écrire le COMMENT, c'est que tu fais déjà un plan → arrête-toi, le COMMENT ira dans la skill `plan`.
