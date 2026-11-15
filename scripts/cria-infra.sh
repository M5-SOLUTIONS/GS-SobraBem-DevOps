#
# VERIFIQUE SE ESTA COM A ASSINATURA CORRRETA
#
# az account show
# az account list -o table
# az account set --subscription "nome-da-assinatura-correta"


# Variáveis
RESOURCE_GROUP_NAME="rg-sobrabem"
WEBAPP_NAME="sobrabem-rm563045"
APP_SERVICE_PLAN="sobrabem-free"
LOCATION="canadacentral"
RUNTIME="JAVA:21-java21"
USERNAME="rm563045"
PASSWORD="241203"
URL="jdbc:oracle:thin:@//oracle.fiap.com.br:1521/ORCL"


# Registrar os Serviços utilizados
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.ServiceLinker

# Registrar a extensão utilizada
az extension add --name application-insights

# Criação do Grupo de Recursos
az group create \
  --name $RESOURCE_GROUP_NAME \
  --location "$LOCATION"

# Criar o Plano de Serviço
az appservice plan create \
  --name $APP_SERVICE_PLAN \
  --resource-group $RESOURCE_GROUP_NAME \
  --location "$LOCATION" \
  --sku F1 \
  --is-linux


# Criar o Serviço de Aplicativo
az webapp create \
  --name $WEBAPP_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --plan $APP_SERVICE_PLAN \
  --runtime "$RUNTIME"

# Configurar as Variáveis de Ambiente necessárias do nosso App
az webapp config appsettings set \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --settings \
    SPRING_DATASOURCE_USERNAME="$USERNAME" \
    SPRING_DATASOURCE_PASSWORD="$PASSWORD" \
    SPRING_DATASOURCE_URL="$URL"

# Reiniciar o Web App
az webapp restart --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP_NAME