using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Azure;
using Azure.AI.OpenAI;
using Azure.AI.OpenAI.Chat;
using OpenAI.Chat;
using System.Text.Json;
using Markdig;

namespace App.Pages;

public class IndexModel : PageModel
{
    private readonly IConfiguration _configuration;
    private readonly string _serviceKey;
    private readonly string _serviceEndpoint;
    private readonly string _serviceDeployment;
    private readonly string _searchServiceEndpoint;
    private readonly string _searchServiceKey;
    private readonly string _searchIndex;
    private readonly string intent;
    private List<string> citations = new List<string>();

    public IndexModel(IConfiguration configuration)
    {
        _configuration = configuration;
        _serviceKey = _configuration.GetValue<string>("ServiceKey") ?? "KEY NOT SET";
        _serviceEndpoint = _configuration.GetValue<string>("ServiceEndpoint") ?? "ENDPOINT NOT SET";
        _serviceDeployment = _configuration.GetValue<string>("DeploymentName") ?? "DEPLOYMENT NOT SET";
        _searchServiceKey = _configuration.GetValue<string>("SearchServiceKey") ?? "SEARCH KEY NOT SET";
        _searchServiceEndpoint = _configuration.GetValue<string>("SearchServiceEndpoint") ?? "SEARCH ENDPOINT NOT SET";
        _searchIndex = _configuration.GetValue<string>("SearchIndex") ?? "SEARCH INDEX NOT SET";
    }

    public async Task<IActionResult> OnPostProcessInputAsync(string UserText, string SystemText)
    {

        // Process the input text
        string userPrompt = UserText;
        string systemPrompt = SystemText + " You ALWAYS return Markdown (MD) because all your results would be rendered in a browser.";

        // Set the original text to output
        ViewData["systemMessage"] = systemPrompt;
        ViewData["userMessage"] = userPrompt;

        // Create a new OpenAI client
        // OpenAIClient client = new(new Uri(_serviceEndpoint), new AzureKeyCredential(_serviceKey));
#pragma warning disable AOAI001
        // Create a new chat completions options object
        AzureOpenAIClient azureClient = new(
            new Uri(_serviceEndpoint),
            new AzureKeyCredential(_serviceKey));
        ChatClient chatClient = azureClient.GetChatClient(_serviceDeployment);

        ChatCompletionOptions options = new();
        options.AddDataSource(new AzureSearchChatDataSource()
        {
            Endpoint = new Uri(_searchServiceEndpoint),
            IndexName = _searchIndex,
            Authentication = DataSourceAuthentication.FromApiKey(_searchServiceKey),
        });

        ChatCompletion completion = chatClient.CompleteChat(
            [
                new SystemChatMessage (systemPrompt),
                new UserChatMessage(userPrompt),
    ], options);


        AzureChatMessageContext onYourDataContext = completion.GetAzureMessageContext();
        ViewData["Completion"] = Markdig.Markdown.ToHtml(completion.Content[0].Text);

        if (onYourDataContext?.Intent is not null)
        {
            ViewData["Intent"] = onYourDataContext.Intent;
        }
        foreach (AzureChatCitation citation in onYourDataContext?.Citations ?? [])
        {
            citations.Add($"<a href=\"{citation.Url}\">Citation</a><br />{Markdig.Markdown.ToHtml(citation.Content)}");

        }
        ViewData["Citations"] = citations;
        return Page();
    }

    public void OnGet()
    {

    }
}
