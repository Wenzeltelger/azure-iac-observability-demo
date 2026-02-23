# Infraestructura (Bicep)

Este módulo despliega:

- App Service Plan (F1)
- Azure App Service
- Application Insights
- Configuración básica de App Settings
- Tags estándar

Despliegue manual:

```bash
az deployment group create \
  --resource-group <RG_NAME> \
  --template-file main.bicep \
  --parameters appName=<APP_NAME>