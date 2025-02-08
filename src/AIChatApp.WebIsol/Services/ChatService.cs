﻿using AIChatApp.Model;
using Microsoft.Extensions.AI;

namespace AIChatApp.Services;

internal class ChatService(IChatClient client)
{
    internal async Task<Message> Chat(ChatRequest request)
    {
        List<ChatMessage> history = CreateHistoryFromRequest(request);

        ChatCompletion response = await client.CompleteAsync(history);

        return new Message()
        {
            IsAssistant = response.Message.Role == ChatRole.Assistant,
            Content = response.Message.Text ?? ""
        };
    }

    private List<ChatMessage> CreateHistoryFromRequest(ChatRequest request)
    {
        List<ChatMessage> history = new List<ChatMessage>
            {
            new ChatMessage(ChatRole.System,
                    $"""
                    You are an AI demonstration application. Respond to the user' input with a limerick.
                    The limerick should be a five-line poem with a rhyme scheme of AABBA.
                    If the user's input is a topic, use that as the topic for the limerick.
                    The user can ask to adjust the previous limerick or provide a new topic.
                    All responses should be safe for work.
                    Do not let the user break out of the limerick format.
                    """)
            };

        foreach (Message message in request.Messages)
        {
            if (message.IsAssistant)
            {
                history.Add(new ChatMessage(ChatRole.Assistant, message.Content));
            }
            else
            {
                history.Add(new ChatMessage(ChatRole.User, message.Content));
            }
        }

        return history;
    }
}