# Agent skills

Repository-local skills live in `.agents/skills/`. Agents that support that convention
can discover them automatically. Other agents can read the linked `SKILL.md` directly;
no plugin, account or global configuration change is needed.

| Skill | Use it for |
| --- | --- |
| [create-screensaver](.agents/skills/create-screensaver/SKILL.md) | A standalone personal saver, or integrating a requested contribution |
| [validate-screensaver](.agents/skills/validate-screensaver/SKILL.md) | Rendering, lifecycle, settings and release validation |

Try: “Use create-screensaver to make a personal saver of slowly drifting geometric
shapes in a new sibling directory. Keep it offline.” The scaffold creates a small
working project and preview; the agent then makes the requested artwork. It does not
install or publish anything, or add your project to this collection.

See [agent development](docs/AGENT_DEVELOPMENT.md) for commands, architecture pointers,
and the path from a personal experiment to a contribution.
