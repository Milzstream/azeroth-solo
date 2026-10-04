#include "gtest/gtest.h"

#include "mod-ollama-chat_response.h"

TEST(OllamaAssistantSpeak, CatchesChatbotBoilerplate)
{
    EXPECT_TRUE(LooksLikeAssistantSpeak("I'll keep that in mind for my responses moving forward."));
    EXPECT_TRUE(LooksLikeAssistantSpeak("I'm happy to help, but this conversation has just begun."));
    EXPECT_TRUE(LooksLikeAssistantSpeak("As an AI I cannot do that"));
    EXPECT_TRUE(LooksLikeAssistantSpeak("LET ME KNOW IF YOU need anything"));
}

TEST(OllamaAssistantSpeak, LeavesNormalPlayerTalkAlone)
{
    EXPECT_FALSE(LooksLikeAssistantSpeak("lol no idea, just passing through"));
    EXPECT_FALSE(LooksLikeAssistantSpeak("Anyone want to clear the kobold camp?"));
    EXPECT_FALSE(LooksLikeAssistantSpeak("Moving forward on the quest chain now"));
    EXPECT_FALSE(LooksLikeAssistantSpeak(""));
}

TEST(OllamaAssistantSpeak, PipelineDropsAssistantReplies)
{
    EXPECT_TRUE(ProcessLlmResponse("I'll keep that in mind for my responses moving forward.", "Laria").empty());
}
