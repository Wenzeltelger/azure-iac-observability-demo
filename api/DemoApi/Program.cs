using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

app.MapGet("/health", () =>
{
    return Results.Ok(new { status = "ok", timestamp = DateTime.UtcNow });
});

app.MapGet("/secret", async () =>
{
    var keyVaultUri = builder.Configuration["KEYVAULT_URI"];
    var secretName = builder.Configuration["SECRET_NAME"];

    if (string.IsNullOrEmpty(keyVaultUri) || string.IsNullOrEmpty(secretName))
        return Results.BadRequest("Key Vault configuration missing.");

    var client = new SecretClient(new Uri(keyVaultUri), new DefaultAzureCredential());

    var secret = await client.GetSecretAsync(secretName);

    return Results.Ok(new
    {
        loaded = true,
        masked = secret.Value.Value.Substring(0, 4) + "****"
    });
});

app.Run();