using System.ClientModel.Primitives;
using Azure.Core;
using Azure.AI.OpenAI;
using System.ClientModel;
using OpenAI.Chat;
using System.Text.RegularExpressions;

namespace Azure.AI;

/// <summary>
/// A rudimentary derivation of <see cref="AzureOpenAIClient"/> that customizes behavior for use of direct model deployments.
/// </summary>
/// <remarks>
/// Key adjustments include:
/// <list type="bullet">
/// <item>Requests remove the infixed /openai/deployments/{deployment-name} from their URIs</item>
/// <item><c>api-key</c> header values (Azure OpenAI) are moved into <c>Authorization: Bearer {key}</c> (OpenAI)</item>
/// <item><see cref="GetChatClient"/> returns a chat client without providing a model or deployment name</item>
/// </list>
/// </remarks>
public class AzureDirectDeploymentClient : AzureOpenAIClient
{
    public AzureDirectDeploymentClient(
        Uri endpoint,
        ApiKeyCredential credential,
        AzureOpenAIClientOptions? options = null)
            : base(endpoint, credential, GetSupplementedOptions(options))
    { }

    public AzureDirectDeploymentClient(
        Uri endpoint,
        TokenCredential tokenCredential,
        AzureOpenAIClientOptions? options = null)
            : base(endpoint, tokenCredential, GetSupplementedOptions(options))
    { }

    public ChatClient GetChatClient()
    {
        return GetChatClient("direct-deployment-placeholder");
    }

    private static AzureOpenAIClientOptions GetSupplementedOptions(AzureOpenAIClientOptions? options)
    {
        options ??= new();

        options.AddPolicy(new DirectDeploymentAdapterPolicy(), PipelinePosition.BeforeTransport);

        return options;
    }

    private class DirectDeploymentAdapterPolicy : PipelinePolicy
    {
        public override void Process(PipelineMessage message, IReadOnlyList<PipelinePolicy> pipeline, int currentIndex)
        {
            MoveApiKeyHeader(message);
            AdjustRequestUri(message);
            ProcessNext(message, pipeline, currentIndex);
        }

        public override async ValueTask ProcessAsync(PipelineMessage message, IReadOnlyList<PipelinePolicy> pipeline, int currentIndex)
        {
            MoveApiKeyHeader(message);
            AdjustRequestUri(message);
            await ProcessNextAsync(message, pipeline, currentIndex);
        }

        private static void MoveApiKeyHeader(PipelineMessage message)
        {
            if (message.Request?.Headers?.TryGetValue("api-key", out string? apiKeyValue) == true)
            {
                //message.Request.Headers.Remove("api-key");
                //message.Request.Headers.Set("Authorization", $"Bearer {apiKeyValue}");
            }
        }

        private static void AdjustRequestUri(PipelineMessage message)
        {
            string? absoluteRequestUri = message?.Request?.Uri?.AbsoluteUri;
            if (absoluteRequestUri is not null)
            {
                //absoluteRequestUri = Regex.Replace(absoluteRequestUri, "/openai/deployments/[^/]*", "");
                //absoluteRequestUri = UriConverter.ConvertUri(absoluteRequestUri);
                message!.Request.Uri = new(absoluteRequestUri);
            }
        }
    }
}