# oMLX host

A script run from another Mac over SSH that sets up the [oMLX](https://github.com/jundot/omlx) LLM server on
an Apple silicon Mac for the `personal` agent of the [OpenClaw host](../openclaw/README.md). `setup` connects
as an administrator of that Mac.

## What setup builds

- A LaunchDaemon runs the server from startup, with nobody logged in, as the standard account `omlx`, so that
  a hole in oMLX reaches no further than that account. The account is hidden from the login window and has
  no login shell.
- The oMLX app of a pinned version, checked against its SHA-256 and signature, in `/opt/omlx/<version>`
  (owned by root). The LaunchDaemon starts the bundled `omlx-cli serve` without the menu bar app. The app
  ships oMLX's native kernels, which some models need and a Homebrew install builds only with full Xcode.
- oMLX listens on 127.0.0.1 only and requires an API key. The main key stays in the `omlx` account's
  `~/.omlx/settings.json`; OpenClaw gets a separate sub key.
- Tailscale Serve publishes only `/v1/chat/completions` and `/v1/embeddings` on port 443. The admin pages,
  model loading, MCP and web tools stay unpublished.
- pf keeps the `omlx` account off the local network (see [../lib/lan-block.sh](../lib/lan-block.sh)).
  Every account can still make tailscaled open tailnet connections, so the tailnet policy gives this Mac
  (`tag:omlx`) no outgoing access at all; SSH from it to your other Macs stops working.
- `~/.config/omlx/client.env` for the administrator: the URL, sub key and models that
  `scripts/openclaw/setup --omlx` reads.

`setup` does not choose models. They are downloaded and set up in the oMLX admin pages, and `setup` finds the
two that OpenClaw uses by their alias.

## Models

| Alias | Model for |
| --- | --- |
| `chat` | the `personal` agent |
| `embedding` | the memory search of both agents |

To open the admin pages from your Mac:

1. `ssh -L 8000:127.0.0.1:8000 <user@host>`. In that session,
   `sudo jq -r .auth.api_key ~omlx/.omlx/settings.json` shows the key to log in with.
2. Open http://localhost:8000/admin and log in.

To change a model:

1. Models > Downloader: download the new model from Hugging Face.
2. Settings > Model Settings: clear Model Alias on the old model, set it on the new one, and pin the new one so
   it stays loaded. Ctx Window and Max Tokens there are the limits OpenClaw is told; they default to the
   model's own context length and 32768 tokens. OpenClaw compacts a conversation into a summary as it nears
   Ctx Window, so a Ctx Window below the model's own length keeps prompts quick to process.
3. Run `scripts/omlx/setup <user@host>`, then `scripts/openclaw/setup <user@openclaw-host> --omlx <user@host>`.
4. Models > Manager: delete the old model.

A new chat model answers as soon as it has the alias; step 3 tells OpenClaw its limits and whether it reads
images. A new embedding model is used only after step 3, which rebuilds the memory index of both agents, since
an index built with one embedding model cannot be searched with another.

## Before the first run

1. The Mac has the `cui` role, so tailscaled runs as a daemon, and tailscaled is 1.98 or later: older
   versions dial non-tailnet addresses for `tailscale nc` themselves, as root, which would let the `omlx`
   account reach the local network.
2. In the Tailscale admin console: the policy from
   [../openclaw/tailnet-policy.hujson](../openclaw/tailnet-policy.hujson), the tag `tag:omlx` on this Mac,
   and HTTPS certificates on.

## Commands

| To | Run |
| --- | --- |
| set up, apply changes to this folder, or pass a model change on to OpenClaw | `scripts/omlx/setup <user@host>` |

The first run creates the `omlx` account (it asks for a password, but nobody logs in to it), starts the server
and stops because no model has an alias yet: download the models and set the aliases as in [Models](#models),
then run `setup` again. `setup` checks both models through Tailscale Serve, checks that the `omlx` account
cannot reach the router and that this Mac cannot reach other tailnet devices, and then writes `client.env`.

To upgrade oMLX, change `OMLX_VERSION` and `OMLX_DMG_SHA256` in [remote/setup.sh](remote/setup.sh) (the
GitHub release lists the digest of each asset) and run `setup` again.
