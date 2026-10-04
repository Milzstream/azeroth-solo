# Intent layer

Grouped bots can act on what their master says. "Want to quest together?" used to get a chat
reply and nothing else, because this module only produces text and playerbots keeps the bot
on `+follow` from the moment it joins ([PlayerbotAI.cpp](../mod-playerbots/src/Bot/PlayerbotAI.cpp)).

## How it works

1. `ProcessChat` sees a real player's party, raid or whisper line.
2. For each eligible bot whose master is that player, `OllamaIntent_MaybeSubmit` checks
   `OllamaChat.Intent.Enable`, a cheap keyword pre-filter (`Intent_LooksActionable`) and a
   per-bot cooldown. Small talk never costs an LLM call.
3. A worker sends a classifier prompt (`Intent_BuildPrompt`) and reads the reply with
   `Intent_ParseReply`. The first whitelisted word wins; anything else is `none`.
4. Back on the world thread, `OllamaIntent_Apply` re-resolves bot and master and runs the plan.

The model only ever chooses a word. It cannot name a command or a strategy.

| Word | Plan |
| --- | --- |
| `follow` | non-combat strategies `-new rpg,+follow` |
| `stay` | chat command `stay` |
| `grind` | chat command `grind` |
| `quest` | strategies `-follow,+new rpg`, then chat command `rpg status do quest` |
| `none` | nothing |

Plans live in `Intent_GetPlan` in `src/mod-ollama-chat_intent_core.cpp`.

## Files

- `src/mod-ollama-chat_intent_core.{h,cpp}`: whitelist, pre-filter, prompt, parser, plans. No engine
  dependencies, so it is unit tested.
- `src/mod-ollama-chat_intent.{h,cpp}`: gating and applying to a live bot.
- `src/mod-ollama-chat_dispatch.cpp`: `TaskType::Intent` and `OllamaDispatch_SubmitIntent`.
- `test/TestIntentCore.cpp`: gtest cases, registered through `ACORE_MODULE_TEST_SOURCES` in
  `mod-ollama-chat.cmake` and built into `unit_tests`.

## Settings

`OllamaChat.Intent.Enable` (default 0) and `OllamaChat.Intent.CooldownSeconds` (default 10).

## Limits and open questions

- Every grouped bot classifies the same line, so a five-man party costs up to four calls. Sharing
  one result per message is a possible improvement.
- The `quest` plan has not been verified in game. Playerbots' new-rpg status update may move a bot
  off `do quest` once it finishes, and `rpg status do quest` picks the first quest in the log that
  has a map position.
- Messages that start with a word in `OllamaChat.BlacklistCommands` (for example `follow`, `stay`,
  `grind`, `quest`) never reach this layer; playerbots handles those natively.
- Bots do not yet loot quest items on request. That is the next candidate intent.

## Related playerbots change

`PlayerbotAI::TellMasterNoFacing` now sends a grouped bot's progress messages (for example
"Kobold Worker 4/10") as party chat instead of a whisper. It applies only when the master is a real
player in the same group as the bot.

## Hosted models (not built yet)

The module only speaks Ollama's `/api/generate`. Using a hosted service would need a provider
option with an OpenAI-style chat endpoint and an API key. Whether a Copilot subscription allows
that use has not been checked.
