#include "mod-ollama-chat_intent.h"
#include "mod-ollama-chat_config.h"
#include "mod-ollama-chat_dispatch.h"
#include "mod-ollama-chat_world.h"

#include "Chat.h"
#include "Group.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "PlayerbotAI.h"
#include "PlayerbotMgr.h"

#include <ctime>
#include <unordered_map>

namespace
{
    // World thread only, so no lock.
    std::unordered_map<uint64_t, time_t> g_lastIntentRequest;
}

void OllamaIntent_MaybeSubmit(Player* bot, Player* speaker, std::string const& message)
{
    if (!g_IntentEnable || !bot || !speaker)
        return;

    if (!OllamaIsRealPlayer(speaker) || (g_IntentPrefilter && !Intent_LooksActionable(message)))
        return;

    PlayerbotAI* botAI = PlayerbotsMgr::instance().GetPlayerbotAI(bot);
    if (!botAI || botAI->GetMaster() != speaker)
        return;

    Group* group = bot->GetGroup();
    if (!group || speaker->GetGroup() != group)
        return;

    time_t const now = time(nullptr);
    uint64_t const botGuid = bot->GetGUID().GetRawValue();
    auto it = g_lastIntentRequest.find(botGuid);
    if (it != g_lastIntentRequest.end() &&
        now - it->second < static_cast<time_t>(g_IntentCooldownSeconds))
        return;
    g_lastIntentRequest[botGuid] = now;

    OllamaDispatch_SubmitIntent(botGuid, speaker->GetGUID().GetRawValue(), bot->GetName(),
                                Intent_BuildPrompt(message));
}

void OllamaIntent_Apply(uint64_t botGuid, uint64_t speakerGuid, BotIntent intent)
{
    Player* bot = ObjectAccessor::FindConnectedPlayer(ObjectGuid(botGuid));
    Player* speaker = ObjectAccessor::FindConnectedPlayer(ObjectGuid(speakerGuid));
    if (!bot || !speaker || !bot->IsInWorld())
        return;

    PlayerbotAI* botAI = PlayerbotsMgr::instance().GetPlayerbotAI(bot);
    // The master may have changed while the model was thinking.
    if (!botAI || botAI->GetMaster() != speaker)
        return;

    BotIntentPlan const plan = Intent_GetPlan(intent);
    if (plan.strategies.empty() && plan.command.empty())
        return;

    if (!plan.strategies.empty())
        botAI->ChangeStrategy(plan.strategies, BOT_STATE_NON_COMBAT);

    if (!plan.command.empty())
        botAI->HandleCommand(CHAT_MSG_WHISPER, plan.command, speaker);

    if (g_DebugEnabled)
        LOG_INFO("module.ollamachat", "[Ollama Chat] Intent {} applied to {} (strategies '{}', command '{}')",
                 Intent_Name(intent), bot->GetName(), plan.strategies, plan.command);
}
