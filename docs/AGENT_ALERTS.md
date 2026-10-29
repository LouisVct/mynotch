# Alertes d'agents IA dans l'encoche

MyNotch affiche une bannière sous l'encoche quand il reçoit un lien `mynotch://agent`.
Ça marche avec n'importe quel outil capable de lancer une commande shell.

## Le lien

```
mynotch://agent?name=<nom>&state=<working|input|done|end>&session=<id>&project=<dossier>&terminal=<bundle id>&message=<texte>
```

- `state`
  - `working` : l'agent travaille. Pastille avec chrono sous l'encoche, pas de bannière.
  - `input` : il attend toi. Bannière orange (30 s).
  - `done` : terminé. Bannière verte (8 s).
  - `end` : la session est fermée, elle disparaît de la liste.
- `session` : identifiant de session. Sans lui, seule la bannière s'affiche, sans suivi.
- `project` : nom affiché dans la liste. `name` : 40 caractères max. `message` : 140 max.
- `terminal` : bundle id de l'app qui héberge l'agent (Terminal, iTerm, VS Code, app Claude...).
  Il active le bouton « aller au terminal ».

Clic sur la pastille = liste des sessions. Les sessions qui ne donnent plus de nouvelles sont retirées
(3 h en travail, 6 h en attente, 30 min une fois terminées).

Test à la main :

```bash
open -g 'mynotch://agent?name=Test&state=working&session=t1&project=demo'
open -g 'mynotch://agent?name=Test&state=input&session=t1&message=Ça%20marche'
open -g 'mynotch://agent?name=Test&state=end&session=t1'
```

## Claude Code

Les hooks sont dans le repo : [integrations/claude-code/](../integrations/claude-code/).
Pour les installer dans `~/.claude/settings.json` (sans toucher au reste, sans doublon, avec une sauvegarde
`settings.json.bak-mynotch`) :

```bash
./integrations/claude-code/install.sh
```

| Hook Claude Code   | État envoyé | Effet                                  |
|--------------------|-------------|----------------------------------------|
| `UserPromptSubmit` | `working`   | pastille « Claude Code » + chrono      |
| `Notification`     | `input`     | bannière orange                        |
| `Stop`             | `done`      | bannière verte                         |
| `SessionEnd`       | `end`       | la session quitte la liste             |

`notify.sh` lit le JSON du hook, retrouve l'app hôte avec `__CFBundleIdentifier` (ou `TERM_PROGRAM`)
et ne fait jamais échouer le hook. Les hooks pointent vers le script du repo : si tu déplaces le dossier,
relance `install.sh`.

## Pomodoro

Bouton minuteur dans l'encoche ouverte (clic = démarrer / pause, clic droit = passer / réinitialiser),
ou via le menu de la barre des menus. Pendant un cycle, un compte à rebours reste sous l'encoche fermée
(clic = pause, clic droit = passer / réinitialiser). Durées et options dans Réglages > Comportement > Pomodoro.

## Autres agents (agy, etc.)

Je n'ai pas vérifié si agy propose des hooks. Sans hook, on peut enchaîner la commande :

```bash
agy ...; open -g 'mynotch://agent?name=agy&message=Terminé&state=done'
```

## Sécurité

Tout programme local (et un lien dans un navigateur) peut afficher une bannière : elle ne contient que du texte
et n'exécute rien. Désactivable dans Réglages > Comportement > « Show alerts from AI coding agents ».
