---
name: choosing-a-pattern
description: "Choix de pattern Rails : quel pattern écrire pour quel besoin (controller direct, méthode de modèle, interactor, query object, form object, state machine, vue, client API). À utiliser pour décider OÙ placer une logique ou QUEL pattern écrire. Pour le style de code Ruby transverse, voir la skill ruby-style ; pour l'implémentation d'un pattern donné, voir sa skill dédiée."
globs:
  - "app/**/*.rb"
---

# Rails Patterns Skill

Cette skill **choisit le pattern** : elle décide *quel pattern écrire* pour un besoin donné, puis oriente vers la skill qui en couvre l'implémentation. Elle ne contient aucune convention de code elle-même — le style Ruby transverse (nommage, chaînage, error handling, temps, linting) vit dans `ruby-style`.

## Choisir un pattern

Table de décision *orientée écriture* (« quel pattern écrire »). Complémentaire de la table *navigation* de la skill `explore-rails` (« où est X »).

| Besoin | Pattern | Skill |
|---|---|---|
| Action triviale / CRUD scaffold | Logique **directement dans le controller** | `controllers` |
| Une étape simple, liée à une entité | **Méthode de modèle** (YAGNI, pas de sur-abstraction) | `models`, `principles` |
| Logique métier **au-dessus du scaffold** (multi-étapes, orchestration) | **Organizer + Interactor** (`app/interactors/`), même pour un seul interactor | `interactors` |
| Requête complexe (filtres conditionnels, recherche, jointures) | **Query Object** (`app/queries/`) | `query-objects` |
| Formulaire multi-champs / validation hors modèle | **Form Object** (`app/forms/`) | `form-objects` |
| Cycle de vie / états contraints d'une ressource | **State Machine (AASM)** | `state-machine` |
| Rendu, formulaire DSFR, interactions client | Vues / Turbo / Stimulus | `frontend-rails`, `hotwire` |
| Client API externe / adapter d'infrastructure | Module dans `lib/<client>/` | `api-client`, `authentication` |

**Le seuil central est la complexité, pas le nombre d'étapes.** Tant qu'on reste au niveau d'un scaffold (CRUD direct, une ou deux lignes triviales), la logique reste dans le controller. Dès qu'on le dépasse, on bascule vers le pattern dédié sans attendre d'avoir « assez » de matière pour le justifier — en particulier, on passe en organizer + interactor dès la première étape métier non triviale, pas de service object PORO ad-hoc.

**Style de code transverse.** Une fois le pattern choisi, les conventions d'écriture communes à tous (nommage, résolution des constantes, error handling, fonctions pures, chaînage, imbrication de blocks, temps, linting) sont dans la skill `ruby-style`.
