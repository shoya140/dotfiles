# Scripts

Scripts that set up other Macs for one job each. They run on the Mac you work on and reach the target over SSH,
so `setup` and `mise bootstrap` never run them. Every script is safe to run again: it changes only what differs
and ends with checks.

| Folder | Sets up |
| --- | --- |
| [openclaw](openclaw/README.md) | [OpenClaw](https://docs.openclaw.ai) on a Mac of its own, with two agents you talk to through Telegram |
| [omlx](omlx/README.md) | the [oMLX](https://github.com/jundot/omlx) LLM server that OpenClaw's `personal` agent and memory search use |
| [lib](lib/lan-block.sh) | `lan-block.sh`, the pf anchor both setups use to keep one account off the local network |

Host names, IDs and keys are not in this repo. Hosts are arguments, and secrets are typed into hidden prompts
and stay on the target.

## Before the first run

- Both target Macs have the `cui` role, are on the tailnet with the tags from
  [openclaw/tailnet-policy.hujson](openclaw/tailnet-policy.hujson), and the tailnet has HTTPS certificates on.
- You can SSH to the oMLX host as an administrator, and to the OpenClaw host as the account that will run
  OpenClaw, also an administrator. That account stays logged in to the desktop with the screen locked.
- For OpenClaw: two Telegram bots made with @BotFather, your numeric Telegram user ID, an Anthropic API key and
  a Brave Search API key.

The [openclaw](openclaw/README.md#before-the-first-run) and [omlx](omlx/README.md#before-the-first-run) READMEs
have the details.

## Setting up

1. Set up the oMLX host. The first run creates the `omlx` account, starts the server and stops, because no
   model has an alias yet.

   ```
   scripts/omlx/setup <user@omlx-host>
   ```

2. In the oMLX admin pages, download the models and give them the aliases `chat` and `embedding`
   ([omlx/README.md](omlx/README.md#models)). Then run step 1 again. It ends with `oMLX <version> is set up.`
3. Set up the OpenClaw host. It reads the oMLX settings from the oMLX host, and asks once for the Telegram user
   ID, the bot tokens and the API keys.

   ```
   scripts/openclaw/setup <user@openclaw-host> --omlx <user@omlx-host>
   ```

4. Do the manual steps it prints at the end: open the Control UI, send a message to both bots, and turn off
   group joining for both bots in @BotFather.

## Later

| To | Run |
| --- | --- |
| apply a change to these folders | `scripts/omlx/setup <user@omlx-host>`, `scripts/openclaw/setup <user@openclaw-host>` |
| change a model | the steps in [omlx/README.md](omlx/README.md#models), which end with both setups |
| upgrade oMLX | `OMLX_VERSION` and `OMLX_DMG_SHA256` in [omlx/remote/setup.sh](omlx/remote/setup.sh), then its setup |
| upgrade OpenClaw | `OPENCLAW_VERSION` in [openclaw/remote/setup.sh](openclaw/remote/setup.sh), then its setup |
| back up OpenClaw to a folder here | `scripts/openclaw/backup <user@openclaw-host> <folder>` |
| set up OpenClaw from a backup | `scripts/openclaw/setup <user@openclaw-host> --restore <archive>` |

After an OpenClaw upgrade, read the doctor's report in the output
([openclaw/README.md](openclaw/README.md#commands)). A backup holds the API keys and bot tokens, so keep it on
an encrypted disk.

## Reading the output

To keep a log, add `2>&1 | tee <file>`. The prompts still work, since they read from the terminal.

The checks at the end print one line each:

- `ok`: passed.
- `FAIL`: needs a look. The setup still finishes, and exits with 1.
- `skip`: could not be checked on this network. The pf check needs a router that does not refuse ports 80 and
  443 by itself.
- An indented line under the security audit is one of its findings, not a failure. The warning
  `config.insecure_or_dangerous_flags` is expected: OpenClaw lists its own audit suppressions this way.
