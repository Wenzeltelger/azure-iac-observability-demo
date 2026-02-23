using System.Net;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace DemoFunction;

public class Secret
{
    [Function("secret")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "secret")] HttpRequestData req)
    {
        var keyVaultUri = Environment.GetEnvironmentVariable("KEYVAULT_URI");
        var secretName = Environment.GetEnvironmentVariable("SECRET_NAME");

        if (string.IsNullOrWhiteSpace(keyVaultUri) || string.IsNullOrWhiteSpace(secretName))
        {
            var bad = req.CreateResponse(HttpStatusCode.InternalServerError);
            await bad.WriteStringAsync("Missing KEYVAULT_URI or SECRET_NAME app settings.");
            return bad;
        }

        var client = new SecretClient(new Uri(keyVaultUri), new DefaultAzureCredential());
        var secret = await client.GetSecretAsync(secretName);

        var res = req.CreateResponse(HttpStatusCode.OK);
        res.Headers.Add("Content-Type", "application/json");
        await res.WriteStringAsync($$"""{"secretName":"{{secretName}}","value":"{{secret.Value.Value}}"}""");
        return res;
    }
}