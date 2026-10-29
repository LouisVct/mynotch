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
  - `clear` : supprime toutes les sessions (badge bloqué) : `open -g 'mynotch://agent?state=clear'`. Même chose via clic droit sur le badge.
- `session` : identifiant de session. Sans lui, seule la bannière s'affiche, sans suivi.
- `project` : nom affiché dans la liste. `name` : 40 caractères max. `message` : 140 max.
- `terminal` : bundle id de l'app qui héberge l'agent (Terminal, iTerm, VS Code, app Claude...).
  Il active le bouton « aller au terminal ».

Clic sur la pastille = liste des sessions. Les sessions qui ne donnent plus de nouvelles sont retirées
(3 h en travail, 1 h en attente, 15 s une fois terminées).

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
| `PostToolUse`      | `working`   | repasse en « travail » après une permission accordée (~0,1 s de surcoût par outil ; retire ce hook si ça te gêne) |

La notification « Claude is waiting for your input » (60 s après la fin) est ignorée : la bannière « terminé » suffit.

`notify.sh` lit le JSON du hook, retrouve l'app hôte avec `__CFBundleIdentifier` (ou `TERM_PROGRAM`)
et ne fait jamais échouer le hook. Les hooks pointent vers le script du repo : si tu déplaces le dossier,
relance `install.sh`.

## Dans l'encoche fermée (façon Live Activity iPhone)

- **Minuteur** : tout en orange comme sur l'iPhone. Une icône minuteur à gauche du cran, le compte à rebours à droite
  (à la place des barres de musique si elle joue). Un clic ouvre l'encoche sur le panneau Minuteur.
- **Agents** : à gauche du cran (spinner = travail, point d'exclamation orange = t'attend, coche verte = terminé, nombre = plusieurs sessions).
  Si la musique occupe la gauche, une petite pastille « N agents » apparaît sous l'encoche.
- Un clic sur le badge ou la pastille ouvre la liste des sessions ; un clic sur une ligne ramène à la fenêtre de la session.
- Plusieurs sessions : une bannière par session (3 maximum). Un clic sur une bannière ramène à la fenêtre et la ferme ;
  la croix la ferme seulement. Une session terminée disparaît d'elle-même après 15 s.

## Panneau Minuteur (encoche ouverte)

Bouton minuteur dans l'en-tête de l'encoche ouverte.
- **À l'arrêt** : durée en grand avec − / +, préréglages 1 · 5 · 10 · 15 · 25 · 30 · 45 · 60 min (un clic = démarre tout de suite),
  case « pause après » (mode Pomodoro), gros bouton orange pour démarrer.
- **En cours** : compte à rebours en grand, barre de progression, bouton pause / reprise (orange) et bouton **✕ pour annuler**
  (revient aux préréglages).
- Clic droit sur le bouton ou sur le minuteur de l'encoche : durées de focus et de pause, passer la phase, réinitialiser.
- Réglages plus fins (pause longue, démarrage automatique, son) : Réglages > General > Pomodoro.

## Autres outils (n'importe lequel)

Le lien `mynotch://agent` est l'interface commune : tout programme capable de lancer une commande peut s'en servir.
Deux scripts du dossier [integrations](../integrations/) évitent d'écrire le lien à la main :

```bash
# Un événement ponctuel (états : working, input, done, end)
integrations/mynotch-notify --name "Mon outil" --state input --message "J'ai besoin de toi"

# Entoure n'importe quelle commande : spinner pendant qu'elle tourne, vert si ça finit, orange si ça échoue
integrations/mynotch-run --name "Build" -- make all
integrations/mynotch-run --name "Aider" -- aider
```

Un clic sur la bannière ou le badge ramène à l'app qui a lancé la commande (Terminal, iTerm, VS Code, Ghostty, Warp,
app Claude...). Pour une autre app, passe son identifiant avec `--app com.exemple.app`.

- **Claude Code** : hooks fournis (voir plus haut).
- **Codex CLI** : [integrations/codex/notify.sh](../integrations/codex/notify.sh), à mettre dans `notify = [...]` de
  `~/.codex/config.toml`. Non testé.
- **Les autres (agy, Aider, Gemini CLI, Cursor...)** : je n'ai pas vérifié leurs mécanismes de hooks. Quand l'outil
  propose une commande de notification, mets-y `mynotch-notify`. Sinon, lance-le avec `mynotch-run`.
