#include "mod-ollama-chat_intent_core.h"

#include <algorithm>
#include <array>
#include <cctype>

namespace
{
    constexpr size_t kMaxMessageChars = 200;

    std::string ToLower(std::string const& text)
    {
        std::string out = text;
        std::transform(out.begin(), out.end(), out.begin(),
                       [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        return out;
    }

    // Quotes and line breaks would let a player close the quoted message in the
    // prompt and append instructions of their own.
    std::string Sanitise(std::string const& text)
    {
        std::string out;
        out.reserve(std::min(text.size(), kMaxMessageChars));
        for (unsigned char c : text)
        {
            if (out.size() >= kMaxMessageChars)
                break;
            if (c == '"' || c == '\\')
                out.push_back('\'');
            else if (c < 0x20)
                out.push_back(' ');
            else
                out.push_back(static_cast<char>(c));
        }
        return out;
    }

    struct Entry
    {
        char const*   word;
        BotIntent     intent;
    };

    constexpr std::array<Entry, 5> kIntents = { {
        { "none",   BotIntent::None   },
        { "follow", BotIntent::Follow },
        { "stay",   BotIntent::Stay   },
        { "grind",  BotIntent::Grind  },
        { "quest",  BotIntent::Quest  },
    } };

    constexpr std::array<char const*, 14> kHints = { {
        "quest", "together", "with me", "help me", "come", "wait", "stay", "follow",
        "grind", "kill", "farm", "let's", "lets", "finish",
    } };
}

bool Intent_LooksActionable(std::string const& message)
{
    std::string const lower = ToLower(message);
    for (char const* hint : kHints)
        if (lower.find(hint) != std::string::npos)
            return true;
    return false;
}

std::string Intent_BuildPrompt(std::string const& message)
{
    return "You are the decision part of a World of Warcraft companion. "
           "Your party leader said: \"" + Sanitise(message) + "\"\n"
           "Pick the ONE action the leader is asking you to take:\n"
           "follow - walk with the leader and stay close\n"
           "stay - hold this position and wait\n"
           "grind - fight monsters nearby for experience\n"
           "quest - work on your current quests together with the leader\n"
           "none - the message is not a request for any of these\n"
           "Answer with exactly one word from the list and nothing else.";
}

BotIntent Intent_ParseReply(std::string const& reply)
{
    std::string const lower = ToLower(reply);

    size_t i = 0;
    while (i < lower.size())
    {
        if (!std::isalpha(static_cast<unsigned char>(lower[i])))
        {
            ++i;
            continue;
        }

        size_t j = i;
        while (j < lower.size() && std::isalpha(static_cast<unsigned char>(lower[j])))
            ++j;

        std::string const word = lower.substr(i, j - i);
        for (Entry const& entry : kIntents)
            if (word == entry.word)
                return entry.intent;

        i = j;
    }

    return BotIntent::None;
}

char const* Intent_Name(BotIntent intent)
{
    for (Entry const& entry : kIntents)
        if (entry.intent == intent)
            return entry.word;
    return "none";
}

BotIntentPlan Intent_GetPlan(BotIntent intent)
{
    switch (intent)
    {
        case BotIntent::Follow:
            return { "-new rpg,+follow", "" };
        case BotIntent::Stay:
            return { "", "stay" };
        case BotIntent::Grind:
            return { "", "grind" };
        case BotIntent::Quest:
            return { "-follow,+new rpg", "rpg status do quest" };
        case BotIntent::None:
        default:
            return {};
    }
}
