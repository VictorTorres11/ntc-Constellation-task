// ASP.NET Core Minimal APIs
// https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis
// https://learn.microsoft.com/en-us/dotnet/core/extensions/httpclient-factory

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHttpClient();
var app = builder.Build();

var buildInfo = new {
    service = "ntc-Constellation API",
    version = Environment.GetEnvironmentVariable("APP_VERSION"),
    commit = Environment.GetEnvironmentVariable("GIT_SHA"),
    builtAt = Environment.GetEnvironmentVariable("BUILD_TIME"),
    environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT"),
    slot = Environment.GetEnvironmentVariable("DEPLOY_SLOT"),
    hostname = Environment.MachineName,
    startedAt = DateTime.UtcNow.ToString("o")
};

app.MapGet("/", () => Results.Ok(buildInfo));

app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

app.MapGet("/load-test", async (HttpContext ctx, IHttpClientFactory factory, int requests = 20) =>
{
    requests = Math.Clamp(requests, 1, 200);
    var client = factory.CreateClient();
    var baseUrl = $"{ctx.Request.Scheme}://{ctx.Request.Host}";
    var results = new List<object>();

    for (int i = 0; i < requests; i++)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        var res = await client.GetAsync($"{baseUrl}/health");
        sw.Stop();
        results.Add(new { request = i + 1, status = (int)res.StatusCode, elapsedMs = sw.ElapsedMilliseconds });
    }

    return Results.Ok(new { total = requests, baseUrl, results });
});

app.Run();
