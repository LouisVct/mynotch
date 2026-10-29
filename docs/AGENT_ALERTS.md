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

Les hooks sont dans le repo : [integrations/claude-code/hooks.json](../integrations/claude-code/hooks.json).
Pour les installer dans `~/.claude/settings.json` (sans toucher au reste, sans doublon, avec une sauvegarde
`settings.json.bak-mynotch`) :

```bash
./integrations/claude-code/install.sh
```

- `Notification` : Claude attend une permission ou ta réponse (bannière orange)
- `Stop` : Claude a fini (bannière verte)

## Autres agents (agy, etc.)

Je n'ai pas vérifié si agy propose des hooks. Sans hook, on peut enchaîner la commande :

```bash
agy ...; open -g 'mynotch://agent?name=agy&message=Terminé&state=done'
```

## Sécurité

Tout programme local (et un lien dans un navigateur) peut afficher une bannière : elle ne contient que du texte
et n'exécute rien. Désactivable dans Réglages > Comportement > « Show alerts from AI coding agents ».
