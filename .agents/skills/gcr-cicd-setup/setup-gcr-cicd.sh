#!/bin/bash

# setup-gcr-cicd.sh
# Automates the configuration of Workload Identity Federation and Service Accounts
# in GCP, and generates the GitHub Actions YAML for Cloud Run deployment.

set -e

PROJECT_ID=$1
GITHUB_OWNER=$2
GITHUB_REPO=$3

if [ -z "$PROJECT_ID" ] || [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ]; then
    echo "❌ Error fatal: Faltan argumentos."
    echo "Uso interno: ./setup-gcr-cicd.sh <PROJECT_ID> <GITHUB_OWNER> <GITHUB_REPO>"
    exit 1
fi

echo "🚀 Iniciando configuración de CI/CD en GCP para $PROJECT_ID..."
gcloud config set project $PROJECT_ID > /dev/null 2>&1

echo "🔍 Autodescubriendo PROJECT_NUMBER..."
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
if [ -z "$PROJECT_NUMBER" ]; then
    echo "❌ Error: No se pudo obtener el PROJECT_NUMBER. Verifica tus permisos en GCP o el PROJECT_ID."
    exit 1
fi
echo "✅ PROJECT_NUMBER detectado: $PROJECT_NUMBER"

echo "📦 Habilitando APIs requeridas..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com iamcredentials.googleapis.com --project=$PROJECT_ID > /dev/null 2>&1 || true

echo "👤 Creando Service Accounts..."
gcloud iam service-accounts create app-runner-sa \
    --display-name="Runtime Service Account" \
    --project=$PROJECT_ID 2>/dev/null || echo "ℹ️ app-runner-sa ya existe, ignorando creación."

gcloud iam service-accounts create github-deployer-sa \
    --display-name="GitHub Actions Deployer" \
    --project=$PROJECT_ID 2>/dev/null || echo "ℹ️ github-deployer-sa ya existe, ignorando creación."

echo "🔐 Asignando roles..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:app-runner-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/logging.logWriter" > /dev/null 2>&1 || true

for ROLE in "roles/run.admin" "roles/cloudbuild.builds.builder" "roles/serviceusage.serviceUsageConsumer" "roles/iam.serviceAccountTokenCreator" "roles/artifactregistry.admin"; do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:github-deployer-sa@$PROJECT_ID.iam.gserviceaccount.com" \
      --role="$ROLE" > /dev/null 2>&1 || true
done

echo "🤝 Configurando impersonación..."
gcloud iam service-accounts add-iam-policy-binding app-runner-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --member="serviceAccount:github-deployer-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser" \
    --project=$PROJECT_ID > /dev/null 2>&1 || true

gcloud iam service-accounts add-iam-policy-binding app-runner-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --member="serviceAccount:github-deployer-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountTokenCreator" \
    --project=$PROJECT_ID > /dev/null 2>&1 || true

gcloud iam service-accounts add-iam-policy-binding $PROJECT_NUMBER-compute@developer.gserviceaccount.com \
    --member="serviceAccount:github-deployer-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser" \
    --project=$PROJECT_ID > /dev/null 2>&1 || true

echo "🌐 Configurando Workload Identity..."
gcloud iam workload-identity-pools create github-pool \
    --location="global" \
    --project=$PROJECT_ID 2>/dev/null || echo "ℹ️ github-pool ya existe."

gcloud iam workload-identity-pools providers create-oidc github-provider \
    --workload-identity-pool="github-pool" \
    --location="global" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository_owner == '$GITHUB_OWNER'" \
    --project=$PROJECT_ID 2>/dev/null || echo "ℹ️ github-provider ya existe."

echo "🔗 Vinculando el repositorio GitHub con el Workload Identity Pool..."
gcloud iam service-accounts add-iam-policy-binding github-deployer-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/$GITHUB_OWNER/$GITHUB_REPO" \
    --project=$PROJECT_ID > /dev/null 2>&1 || true

echo "📄 Generando archivo YAML de GitHub Actions..."
mkdir -p .github/workflows

cat <<EOF > .github/workflows/deploy-dev.yml
name: Deploy DEV

on:
  push:
    branches: [develop]

env:
  PROJECT_ID: \${{ secrets.GCP_PROJECT_ID }}
  SERVICE_NAME: $GITHUB_REPO-dev
  REGION: us-central1

jobs:
  deploy:
    name: Build & Deploy to Cloud Run (DEV)
    runs-on: ubuntu-latest
    
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout del código
        uses: actions/checkout@v4

      - name: Autenticación en Google Cloud
        uses: google-github-actions/auth@v2
        with:
          project_id: '\$PROJECT_ID'
          workload_identity_provider: 'projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
          service_account: 'github-deployer-sa@$PROJECT_ID.iam.gserviceaccount.com'

      - name: Desplegar a Cloud Run
        uses: google-github-actions/deploy-cloudrun@v2
        with:
          service: \${{ env.SERVICE_NAME }}
          region: \${{ env.REGION }}
          source: '.'
          flags: '--allow-unauthenticated --service-account=app-runner-sa@$PROJECT_ID.iam.gserviceaccount.com --set-env-vars ENV=dev,API_KEY=\${{ secrets.DEV_API_KEY }},JWT_SECRET=\${{ secrets.DEV_JWT_SECRET }},AIRTABLE_API_KEY=\${{ secrets.DEV_AIRTABLE_API_KEY }},AIRTABLE_BASE_ID=\${{ secrets.DEV_AIRTABLE_BASE_ID }},AIRTABLE_TABLE_NAME=tblI5hgRqusP8ddjZ'
EOF

echo "✅ Proceso completado exitosamente."
echo "✅ Se creó el archivo .github/workflows/deploy-dev.yml con tus variables inyectadas."
