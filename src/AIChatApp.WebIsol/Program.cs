using AIChatApp.Components;
using AIChatApp.Model;
using AIChatApp.Services;
using Azure.AI;
using Azure.Identity;
using Microsoft.Extensions.AI;
using System.ClientModel;
using System.Web;

var builder = WebApplication.CreateBuilder(args);

// Add service defaults & Aspire components.
builder.AddServiceDefaults();

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();


// Add Microsoft.Extensions.AI. This will use the OpenAI client configured in the line above
var chatDeploymentName = "DeepSeek-R1"; // builder.Configuration["AI_ChatDeploymentName"] ?? "chat";

builder.Services.AddSingleton<IChatClient>(c =>
{
    var logger = c.GetService<ILogger<Program>>()!;
    logger.LogInformation($"==================================================");
    logger.LogInformation($"Register ChatClient for DeepSeekR1");
    logger.LogInformation($"Chat client configuration, modelId: openai");
    logger.LogInformation($"Chat deployment name, modelId: {chatDeploymentName}");
    logger.LogInformation($"==================================================");

    IChatClient chatClient = null;
    var (endpoint, apiKey) = GetEndpointAndKey(builder, "openai");
    if (string.IsNullOrEmpty(apiKey))
    {
        // no apikey, use default azure credential  
        var endpointModel = new Uri(endpoint);
        logger.LogInformation($"DeepSeekR1 No ApiKey, use default azure credentials.");
        logger.LogInformation($"Creating DeepSeekR1 chat client with modelId: [{chatDeploymentName}] / endpoint: [{endpoint}]");

        AzureDirectDeploymentClient directDeploymentClient = new(new Uri(endpoint), new DefaultAzureCredential());
        chatClient = directDeploymentClient.AsChatClient(chatDeploymentName);
    }
    else
    {
        // using ApiKey
        logger.LogInformation($"ApiKey Found, use ApiKey credentials.");
        logger.LogInformation($"Creating DeepSeekR1 chat client with modelId: [{chatDeploymentName}] / endpoint: [{endpoint}] / apiKey length: {apiKey.Length}");
        AzureDirectDeploymentClient directDeploymentClient = new(new Uri(endpoint), new ApiKeyCredential(apiKey));
        //AzureOpenAIClient directDeploymentClient = new(new Uri(endpoint), new ApiKeyCredential(apiKey));
        chatClient = directDeploymentClient.AsChatClient(chatDeploymentName);
    }
    logger.LogInformation($"==================================================");
    return chatClient;

    //var azureClient = c.Services.GetRequiredService<AzureOpenAIClient>();
    //return c.Use(azureClient.AsChatClient(chatDeploymentName));

});


builder.Services.AddTransient<ChatService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);

    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseStaticFiles();

app.UseAntiforgery();

app.MapRazorComponents<App>()
   .AddInteractiveServerRenderMode();

// Configure APIs for chat related features
// Uncomment for a non-streaming response
app.MapPost("/api/chat", (ChatRequest request, ChatService chatHandler) => (chatHandler))
  .WithName("Chat")
  .WithOpenApi();
//app.MapPost("/api/chat/stream", (ChatRequest request, ChatService chatHandler) => chatHandler.Stream(request))
//    .WithName("StreamingChat")
//    .WithOpenApi();

app.Run();

static (string endpoint, string apiKey) GetEndpointAndKey(WebApplicationBuilder builder, string name)
{
    var connectionString = builder.Configuration.GetConnectionString(name);

    // if connectionString is null or empty try to read the value directly
    if (string.IsNullOrEmpty(connectionString))
    {
        connectionString = builder.Configuration[$"connectionstrings--{name}"];
    }

    var parameters = HttpUtility.ParseQueryString(connectionString.Replace(";", "&"));
    return (parameters["Endpoint"], parameters["Key"]);
}