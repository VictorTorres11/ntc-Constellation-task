# Stage 1: Build
# Reference: https://hub.docker.com/_/microsoft-dotnet-sdk
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project file and restore dependencies
COPY *.csproj ./
RUN dotnet restore *.csproj

# Copy source and publish
COPY . ./
RUN dotnet publish -c Release -o /app/publish --no-restore

# Stage 2: Runtime
# Reference: https://hub.docker.com/_/microsoft-dotnet-aspnet
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Copy published output from build stage
ARG GIT_SHA=unknown
ARG BUILD_TIME=unknown
ARG APP_VERSION=1.0.0
ARG DEPLOY_SLOT=unknown

ENV GIT_SHA=$GIT_SHA
ENV BUILD_TIME=$BUILD_TIME
ENV APP_VERSION=$APP_VERSION
ENV DEPLOY_SLOT=$DEPLOY_SLOT

COPY --from=build /app/publish .

# Expose default ASP.NET Core port
EXPOSE 8080

ENTRYPOINT ["dotnet", "aspnetapp.dll"]
