using ImageWebApp.Models;
using Microsoft.AspNetCore.Mvc;
using Azure;
using Azure.AI.Vision.ImageAnalysis;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Text;
using Microsoft.AspNetCore.Http.Features;

namespace _01_analyse_images.Controllers;

public class HomeController : Controller
{
    private readonly IWebHostEnvironment _env; // This field will store the web hosting environment
    private readonly IConfiguration _configuration;
    private readonly string _visionEndpoint;
    private readonly string _visionKey;

    public HomeController(IWebHostEnvironment env, IConfiguration configuration)
    {
        _env = env; // Initialize the field with the constructor parameter
        _configuration = configuration;
        _visionEndpoint = _configuration.GetValue<string>("VisionEndpoint") ?? "ENDPOINT NOT SET";
        _visionKey = _configuration.GetValue<string>("VisionKey") ?? "KEY NOT SET";
    }

    public IActionResult Index()
    {
        return View(); // Return the index view
    }

    [HttpPost]
    public async Task<IActionResult> Index(ImageModel model)
    {

        if (ModelState.IsValid) // Check if the model is valid
        {
            var fileName = Path.GetFileName(model.ImageFile.FileName); // Get the file name of the uploaded image
            var filePath = Path.Combine(_env.WebRootPath, "images", fileName); // Get the file path to save the image in the wwwroot/images folder
            var GenderNeutral = model.GenderNeutral;
            using (var fileStream = new FileStream(filePath, FileMode.Create)) // Create a file stream to write the image data
            {
                await model.ImageFile.CopyToAsync(fileStream); // Copy the image data to the file stream
            }
            ViewBag.ImagePath = "/images/" + fileName; // Set the ViewBag property to store the image path for displaying

            // Authenticate
            ImageAnalysisClient client = new (
                new Uri(_visionEndpoint),
                new AzureKeyCredential(_visionKey));
            
            // Analysis options
            ImageAnalysisOptions analysisOptions = new()
            {
                GenderNeutralCaption = GenderNeutral
            };

            // Open the file in a stream
            using FileStream stream = new(filePath, FileMode.Open);

            // Analyse the image
            ImageAnalysisResult result = client.Analyze(
                BinaryData.FromStream(stream),
                VisualFeatures.Caption |
                VisualFeatures.DenseCaptions |
                VisualFeatures.Tags |
                VisualFeatures.Read |
                VisualFeatures.Objects,
                analysisOptions
            );

            // Get image caption
            if (result.Caption != null)
            {
                ViewBag.Caption = $"{result.Caption.Text} (confidence: {result.Caption.Confidence:0.0000})";
            }

            // Get image dense captions
            if (result.DenseCaptions != null)
            {

                var denseCaptions = new List<string>();

                foreach (var caption in result.DenseCaptions.Values)
                {
                    denseCaptions.Add($"{caption.Text} (confidence: {caption.Confidence:0.0000})");
                }
                ViewBag.DenseCaptions = denseCaptions;

            }

            // Get image tags
            if (result.Tags != null)
            {
                var tags = new List<string>();
                foreach (var tag in result.Tags.Values)
                {
                    tags.Add($"{tag.Name} (confidence: {tag.Confidence:0.0000})");
                }
                ViewBag.Tags = tags;
            }

            // Get detected objects
            if (result.Objects != null)
            {
                var objects = new List<string>();
                foreach (var obj in result.Objects.Values)
                {
                    // Each DetectedObject has a Tags property, which is a list of DetectedTag(s)
                    if (obj.Tags != null && obj.Tags.Count > 0)
                    {
                        var tag = obj.Tags[0];
                        objects.Add($"{tag.Name} (confidence: {tag.Confidence:0.0000})");
                    }
                    else
                    {
                        objects.Add("Unknown object");
                    }
                }
                ViewBag.Objects = objects;
            }

            // Get image text
            if (result.Read != null)
            {
                var lines = new List<string>();
                foreach (var block in result.Read.Blocks)
                {
                    foreach (var line in block.Lines)
                        lines.Add($"{line.Text}");
                }
                ViewBag.Lines = lines;
            }

        }
        return View(model); // Return the index view with the model
 
    }
}
