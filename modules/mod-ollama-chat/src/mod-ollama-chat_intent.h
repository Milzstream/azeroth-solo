#ifndef MOD_OLLAMA_CHAT_INTENT_H
#define MOD_OLLAMA_CHAT_INTENT_H

#include "mod-ollama-chat_intent_core.h"

#include <cstdint>
#include <string>

class Player;

// Engine-facing half of the intent layer; see mod-ollama-chat_intent_core.h
// for the parts that are unit-tested.

// A real player said `message` to a grouped bot. If the bot has them as its
// master and the line could be a request, queue a classification.
// World thread only.
void OllamaIntent_MaybeSubmit(Player* bot, Player* speaker, std::string const& message);

// Carry out a classified intent through playerbots' own strategy and chat
// command paths, resolving both guids again because the bot or master may have
// gone since the request was queued. World thread only.
void OllamaIntent_Apply(uint64_t botGuid, uint64_t speakerGuid, BotIntent intent);

#endif // MOD_OLLAMA_CHAT_INTENT_H
