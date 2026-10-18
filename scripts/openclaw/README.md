# OpenClaw host

Scripts run from another Mac over SSH that set up and back up [OpenClaw](https://docs.openclaw.ai) on a Mac
dedicated to it. The account that runs OpenClaw is an administrator, and `setup` connects as that account.

## What setup builds

- Two agents with their own workspace, sessions, memory index and skills, each bound to its own Telegram bot:
  - `main` uses Claude Opus 5.5 by default; `/model fable`, `opus`, `sonnet` and `haiku` switch models.
  - `personal` uses the model with the alias `chat` in [oMLX](../omlx/README.md) on another Mac, so the
    model can change there without touching this host. `/model local` returns to it, and it can use the
    Claude models when asked. It has no automatic fallback to Claude.
  - Both search the web with Brave and search their memory with embeddings from oMLX.
  - When a conversation nears the model's context window, OpenClaw replaces its older part with a summary. The
    local model needs minutes to read a long conversation, so a summary may take up to 30 minutes, and both
    bots say in the chat when one starts and ends.
- No sandbox: both agents run commands on the host without approval, and the account has passwordless sudo.
- OpenClaw is reachable only through Telegram DMs from the owner and through Tailscale. The gateway listens
  on 127.0.0.1 and OpenClaw publishes it to the tailnet with Tailscale Serve. Bonjour and SSH-verified node
  pairing are off.
- Secrets (the gateway token, the Anthropic and Brave API keys, the bot tokens and the oMLX key) are typed once
  in hidden prompts and kept in OpenClaw's secret store on the host. `openclaw.json` refers to them.
- `setup` renders `openclaw.json` from [remote/openclaw.json](remote/openclaw.json), validates it with the
  installed OpenClaw, and runs the gateway with `OPENCLAW_CONFIG_READONLY=1`, so OpenClaw never rewrites it.
  Switching models with `/model` in a chat still works.

## Keeping the host from reaching other machines

The agents can do anything the account can do, including sudo, so nothing inside the host is trusted to
stop them.

- Tailnet: [tailnet-policy.hujson](tailnet-policy.hujson) tags the host `tag:openclaw` and grants it only
  the oMLX host's HTTPS port. Every device enforces the policy on the traffic it receives, so even root on
  the host cannot reach anything else. Re-tagging needs an admin login to the Tailscale admin console, so
  never sign in to it from the host, and never leave an auth key or API key for the tailnet there.
- Local network: [../lib/lan-block.sh](../lib/lan-block.sh) installs a pf anchor that blocks the account's
  new connections to private, link-local and multicast addresses and to the networks the host is on, and SMB
  and NFS for every user. Root can turn pf off, so this only stops mistakes and tools that respect it; it is
  not a guarantee. OpenClaw's browser and fetch tools also refuse private addresses by default. For a
  guarantee, put the host on a network that reaches only the internet (a guest network or a VLAN).
- Keep on the host no credentials for other machines: SSH keys, tokens that can push to repositories other
  Macs pull from, passwords of other Wi-Fi networks, password managers.
- Do not pair OpenClaw nodes (the macOS or iOS app, `openclaw node`) from other devices: a paired node runs
  the agent's commands. Use Telegram and the Control UI in a browser.
- Connect with SSH without agent forwarding. The scripts turn it off.

## Before the first run

1. On the host, as the account that will run OpenClaw: `~/dotfiles/setup cui` and `sudo tailscale up`.
   Log in to the desktop with Screen Sharing and lock the screen. The gateway is a LaunchAgent, so the
   account must be logged in after every restart.
2. In the Tailscale admin console:
   - Access controls: paste [tailnet-policy.hujson](tailnet-policy.hujson), with your login in `tests`.
   - Machines: add the tag `tag:openclaw` to the host.
   - DNS: MagicDNS and HTTPS certificates on.
3. Set up the oMLX host with [../omlx/setup](../omlx/README.md).
4. Have ready:
   - two Telegram bots made with @BotFather, one for each agent, and their tokens
   - your numeric Telegram user ID (@userinfobot replies with it)
   - an Anthropic API key, ideally from a workspace of its own with a spend limit, since the agents can
     read it
   - a Brave Search API key

## Commands

| To | Run |
| --- | --- |
| set up, or take in a model change on the oMLX host | `scripts/openclaw/setup <user@host> --omlx <user@omlx-host>` |
| apply changes to this folder, or upgrade | `scripts/openclaw/setup <user@host>` |
| back up to a folder on this Mac | `scripts/openclaw/backup <user@host> <folder>` |
| set up and restore a backup | `scripts/openclaw/setup <user@host> --restore <archive>` |

`setup` asks for the sudo password once, then writes `/etc/sudoers.d/openclaw`. It ends with checks: the
security audit, a reply from each agent, the memory index, the Telegram probe, and connections from the host
that the tailnet policy and pf must stop.

`--omlx` reads what `scripts/omlx/setup` wrote on the oMLX host: the URL, the key, the chat model's limits and
whether it reads images, and the embedding model. Run it after changing models there
([../omlx/README.md](../omlx/README.md#models)). When the embedding model changed, the memory index check
rebuilds the index of both agents, since OpenClaw stops vector search on an index built with another model.

The backup is OpenClaw's own `openclaw backup create --verify`: config, state, the secret store, sessions,
memory and workspaces. It includes the API keys and bot tokens, so it is saved with mode 600; keep it on an
encrypted disk. `--restore` moves the current state aside, puts the archive's state in its place, and then
renders a fresh config, so a backup from an older version restores into the current setup.

To upgrade, change `OPENCLAW_VERSION` in [remote/setup.sh](remote/setup.sh) and run `setup` again.
`openclaw update` does not work with the mise install. After an upgrade, `setup` runs `openclaw doctor --fix`,
which cannot change the read-only config. When it reports legacy config keys, apply the merge patch printed
after that report to [remote/openclaw.json](remote/openclaw.json) and run `setup` again.
