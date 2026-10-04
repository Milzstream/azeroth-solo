#ifndef MOD_OLLAMA_CHAT_INTENT_CORE_H
#define MOD_OLLAMA_CHAT_INTENT_CORE_H

#include <cstdint>
#include <string>

// --------------------------------------------------------------------------
// Intent layer, engine-free half.
//
// A grouped bot can act on what its master says ("want to quest together?")
// instead of only chatting about it. The LLM never executes anything: it picks
// ONE word from the fixed list below, and each word maps to a fixed playerbots
// plan. Anything outside the list is ignored.
//
// This file has no AzerothCore or playerbots dependency so the unit tests
// (src/test via ACORE_MODULE_TEST_SOURCES) can link it directly. Applying a
// plan to a live bot lives in mod-ollama-chat_intent.cpp.
// --------------------------------------------------------------------------

enum class BotIntent : uint8_t
{
    None = 0,
    Follow,
    Stay,
    Grind,
    Quest,
};

// What applying an intent means for playerbots. Either field may be empty.
struct BotIntentPlan
{
    // Comma-separated strategy changes for the non-combat engine, in
    // PlayerbotAI::ChangeStrategy syntax ("-follow,+new rpg").
    std::string strategies;

    // A playerbots chat command, exactly as the master would type it.
    std::string command;
};

// Cheap pre-filter. The classifier costs an LLM call, so only lines that could
// plausibly be a request get one. Case-insensitive.
bool Intent_LooksActionable(std::string const& message);

// Classifier prompt for one message. The message is sanitised and length-capped.
std::string Intent_BuildPrompt(std::string const& message);

// Reads the model's reply. The first whitelisted word wins; anything else
// (including an empty reply) is None.
BotIntent Intent_ParseReply(std::string const& reply);

char const* Intent_Name(BotIntent intent);
BotIntentPlan Intent_GetPlan(BotIntent intent);

#endif // MOD_OLLAMA_CHAT_INTENT_CORE_H
