# skills

Mis skills de Claude: cómo le paso el trabajo y cómo quiero que lo lleve.

El repo es un *marketplace* de plugins de Claude Code, así que se instala con un comando y se
actualiza solo. De momento hay un plugin:

| Plugin                         | Skills                                                                                                                          |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| [`orchestrated-dev`](plugins/orchestrated-dev) | `task-workflow` (la operativa al recibir una tarea), `pr-shepherd` (vigilar la PR hasta que se pueda mergear), `status-report` (el «minuto y resultado») |

## Instalar

```
/plugin marketplace add jjballano/skills
/plugin install orchestrated-dev@jjballano-skills
```

Mientras el repo sea privado hace falta acceso de lectura (`gh auth login` y `gh auth setup-git`).
Para que se actualice solo: `/plugin` → *Marketplaces* → `jjballano-skills` → *Enable auto-update*.

Las skills se invocan solas por su descripción o a mano: `/orchestrated-dev:task-workflow`,
`/orchestrated-dev:pr-shepherd`, `/orchestrated-dev:status-report`.

## Qué hace cada una

- **task-workflow**: el hilo principal orquesta y queda libre; el trabajo se trocea en
  subagentes en segundo plano con el modelo más pequeño que lo haga bien; sus dudas van al
  orquestador, no a mí; el orquestador valida cada resultado; se verifica solo lo tocado; diff
  mínimo; cada PR sale con su vigilante.
- **pr-shepherd**: un agente pequeño corre un monitor que solo emite eventos (comentario o review
  nuevos, check en rojo, conflicto, cambio de base, READY, mergeada), lo rearma cuando caduca,
  arregla lo que haga falta y limpia el worktree al mergear. Incluye `scripts/watch-prs.sh` y la
  receta de PRs apiladas y rebases en cascada.
- **status-report**: estado pieza a pieza refrescado en vivo, lo siguiente, y siempre «lo que
  necesito de ti».

## Añadir o cambiar una skill

1. La skill va en `plugins/<plugin>/skills/<skill>/SKILL.md`, en **inglés**, con sus ficheros de
   apoyo dentro de su carpeta (`references/`, `scripts/`, `assets/`). Nada de rutas de mi
   máquina ni de otros repos: tiene que ser autocontenida.
2. Sube la `version` de `plugins/<plugin>/.claude-plugin/plugin.json` en cada cambio; si no,
   el auto-update no lo recoge.
3. Comprueba en local:

   ```bash
   python3 scripts/validate_skills.py
   claude plugin validate . --strict
   claude --plugin-dir plugins/orchestrated-dev     # sesión con el plugin cargado
   ```

En el frontmatter uso solo claves que también acepta claude.ai (`name`, `description`,
`license`, `compatibility`, `metadata`, `allowed-tools`), por si algún día las subo allí.
