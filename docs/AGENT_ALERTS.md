# Alertes d'agents IA dans l'encoche

MyNotch affiche une bannière sous l'encoche quand il reçoit un lien `mynotch://agent`.
Ça marche avec n'importe quel outil capable de lancer une commande shell.

## Le lien

```
mynotch://agent?name=<nom>&message=<texte>&state=<input|done>
```

- `name` : nom affiché (40 caractères max), par défaut « AI agent »
- `message` : texte affiché (140 caractères max)
- `state` : `input` (orange, reste 30 s) ou `done` (vert, reste 8 s). Un clic ferme la bannière.

Test à la main :

```bash
open -g 'mynotch://agent?name=Test&message=Ça%20marche&state=input'
```

`-g` évite de passer l'app au premier plan.

## Claude Code

Dans `~/.claude/settings.json`, ajoute (ou fusionne avec tes `hooks` existants) :

```json
{
  "hooks": {
    "Notification": [
      { "hooks": [ { "type": "command",
        "command": "open -g 'mynotch://agent?name=Claude%20Code&message=Needs%20your%20attention&state=input'" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command",
        "command": "open -g 'mynotch://agent?name=Claude%20Code&message=Finished&state=done'" } ] }
    ]
  }
}
```

`Notification` se déclenche quand Claude attend une permission ou ta réponse, `Stop` quand il a fini.

## Autres agents (agy, etc.)

Je n'ai pas vérifié si agy propose des hooks. Sans hook, on peut enchaîner la commande :

```bash
agy ...; open -g 'mynotch://agent?name=agy&message=Terminé&state=done'
```

## Sécurité

Tout programme local (et un lien dans un navigateur) peut afficher une bannière : elle ne contient que du texte
et n'exécute rien. Désactivable dans Réglages > Comportement > « Show alerts from AI coding agents ».
