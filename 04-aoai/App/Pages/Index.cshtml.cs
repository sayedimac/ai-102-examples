using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Newtonsoft.Json.Linq;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Configuration.Json;
using Azure;

// Add Azure OpenAI package
using Azure.AI.OpenAI;

namespace App.Pages;

public class IndexModel : PageModel
{
    private readonly IConfiguration _configuration;
    private readonly string _serviceKey;
    private readonly string _serviceEndpoint;
    private readonly string _serviceDeployment;
    
    public IndexModel(IConfiguration configuration)
    {
        _configuration = configuration;
        _serviceKey = _configuration.GetValue<string>("ServiceKey") ?? "KEY NOT SET";
        _serviceEndpoint = _configuration.GetValue<string>("ServiceEndpoint") ?? "ENDPOINT NOT SET";
        _serviceDeployment = _configuration.GetValue<string>("DeploymentName") ?? "DEPLOYMENT NOT SET";
    }

    public async Task<IActionResult> OnPostProcessInputAsync(string UserText, string SystemText, string myUserText, string assistantText, bool useFewShot, int temp)
    {

        // Process the input text
        string userPrompt = UserText ?? "";
        string systemPrompt = SystemText ?? "You are an AI chat bot answering general questions";
        string myUserPrompt = myUserText ?? "";
        string assistantPrompt = assistantText ?? "";
        // bool useFewShot = useFewShot;
        float temperature = temp;

        // Set the original text to output
        ViewData["systemMessage"] = systemPrompt;
        ViewData["userMessage"] = userPrompt;
        ViewData["useFewShot"] = useFewShot;
        ViewData["myUserMessage"] = myUserPrompt;
        ViewData["assistantMessage"] = assistantPrompt;


        // Create a new OpenAI client
        OpenAIClient client = new OpenAIClient(new Uri(_serviceEndpoint), new AzureKeyCredential(_serviceKey));

        // Create a new chat completions options object
        if (useFewShot)
        {

            var chatCompletionsOptions = new ChatCompletionsOptions()
            {
                Messages =
        {
            new ChatMessage(ChatRole.System, systemPrompt),
            new ChatMessage(ChatRole.User, myUserPrompt),
            new ChatMessage(ChatRole.Assistant, assistantPrompt),
            new ChatMessage(ChatRole.User, userPrompt)
        },
            Temperature = 0.5f,
            MaxTokens = 800,
            DeploymentName = _serviceDeployment
        };
            Response<ChatCompletions> response = await client.GetChatCompletionsAsync(chatCompletionsOptions);

            ChatCompletions completions = response.Value;
            string completion = completions.Choices[0].Message.Content;
            ViewData["Completion"] = completion;
            return Page();
        }
        else
        {
            var chatCompletionsOptions = new ChatCompletionsOptions()
            {
                Messages =
        {
            new ChatMessage(ChatRole.System, systemPrompt),
            new ChatMessage(ChatRole.User, userPrompt)
        },
                Temperature = temperature / 100,
                MaxTokens = 800,
                DeploymentName = _serviceDeployment
            };
            Response<ChatCompletions> response = await client.GetChatCompletionsAsync(chatCompletionsOptions);

            ChatCompletions completions = response.Value;
            string completion = completions.Choices[0].Message.Content;
            ViewData["Completion"] = completion;
            return Page();

        }
        // Get response from Azure OpenAI
    }

    public void OnGet()
    {
        
    }
}
