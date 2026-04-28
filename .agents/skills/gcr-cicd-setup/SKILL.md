---
name: gcr-cicd-setup
description: "Skill para automatizar la configuración de Workload Identity Federation y Service Accounts en GCP, y generar automáticamente el archivo YAML de GitHub Actions para el despliegue en Cloud Run."
---

# Google Cloud Run CI/CD Setup

## Descripción
Skill para automatizar la configuración de Workload Identity Federation y Service Accounts (Doble arquitectura: runtime y deployer) en GCP, y generar automáticamente el archivo YAML de GitHub Actions para el despliegue en Cloud Run. Esta versión deduce de forma autónoma el `PROJECT_NUMBER`.

## Instrucciones Críticas para el Agente
1. El script `setup-gcr-cicd.sh` es NO interactivo y requiere exactamente **3 parámetros posicionales**: `<PROJECT_ID> <GITHUB_OWNER> <GITHUB_REPO>`. El `PROJECT_NUMBER` será detectado y resuelto automáticamente por el mismo script a través de \`gcloud\`.
2. **SIEMPRE PREGUNTA** al usuario cuáles son el `PROJECT_ID`, `GITHUB_OWNER` y `GITHUB_REPO` que desea usar para el despliegue antes de ejecutar el script. **NUNCA asumas el PROJECT_ID** (incluso si `gcloud config` te devuelve uno por defecto o lo tienes en memoria), ya que el usuario maneja múltiples proyectos y clientes.
3. Haz esta validación en un solo mensaje inicial al usuario, por ejemplo: _"¿Qué PROJECT_ID, GITHUB_OWNER y GITHUB_REPO utilizaremos para esta configuración?"_
4. Una vez tengas los 3 valores, ejecuta el comando en la terminal (usa git bash o bash si el usuario está en un entorno Windows/PowerShell):
   \`bash ./.agents/skills/gcr-cicd-setup/setup-gcr-cicd.sh <PROJECT_ID> <GITHUB_OWNER> <GITHUB_REPO>\`
5. El script se encargará de crear toda la infraestructura de IAM / WIF en GCP y generará la carpeta `.github/workflows/` con el archivo `deploy-dev.yml` configurado con Service Accounts de mínimo privilegio listos para usar en Cloud Run.
6. Al finalizar exitosamente, infórmale al usuario que la configuración está lista en Google Cloud y que su archivo de GitHub Actions fue generado localmente de forma exitosa.
