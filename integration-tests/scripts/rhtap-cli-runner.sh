#!/bin/sh

# Set shell options for better error handling
set -o errexit
set -o nounset
set -o pipefail

# Export environment variables for GitHub and other services
export GITHUB__APP__ID GITHUB__APP__CLIENT__ID GITHUB__APP__CLIENT__SECRET GITHUB__APP__PRIVATE_KEY \
    GITOPS__GIT_TOKEN GITHUB__APP__WEBHOOK__SECRET GITLAB__TOKEN JENKINS_API_TOKEN JENKINS_URL \
    JENKINS_USERNAME

# Path to your values.yaml.tpl file
tpl_file="charts/values.yaml.tpl"

# Enable CI in the values.yaml.tpl file
sed -i 's/ci: false/ci: true/' "$tpl_file"

# Configure GitHub App integration
GITHUB__APP__ID=$(cat /usr/local/rhtap-cli-install/rhdh-github-app-id)
GITHUB__APP__CLIENT__ID=$(cat /usr/local/rhtap-cli-install/rhdh-github-client-id)
GITHUB__APP__CLIENT__SECRET=$(cat /usr/local/rhtap-cli-install/rhdh-github-client-secret)
GITHUB__APP__PRIVATE_KEY=$(base64 -d < /usr/local/rhtap-cli-install/rhdh-github-private-key | sed 's/^/        /')
GITOPS__GIT_TOKEN=$(cat /usr/local/rhtap-cli-install/github_token)
GITHUB__APP__WEBHOOK__SECRET=$(cat /usr/local/rhtap-cli-install/rhdh-github-webhook-secret)
GITLAB__TOKEN=$(cat /usr/local/rhtap-cli-install/gitlab_token)

# Update the developer hub catalog URL
DEVELOPER_HUB__CATALOG__URL="https://github.com/redhat-appstudio/tssc-sample-templates/blob/main/all.yaml"
yq e ".rhtapCLI.features.redHatDeveloperHub.properties.catalogURL = \"${DEVELOPER_HUB__CATALOG__URL}\"" -i config.yaml

# Append GitHub integration details to the values.yaml.tpl file
cat <<EOF >> "$tpl_file"
integrations:
  github:
    id: "${GITHUB__APP__ID}"
    clientId: "${GITHUB__APP__CLIENT__ID}"
    clientSecret: "${GITHUB__APP__CLIENT__SECRET}"
    publicKey: |-
$(echo "${GITHUB__APP__PRIVATE_KEY}" | sed 's/^/      /')
    token: "${GITOPS__GIT_TOKEN}"
    webhookSecret: "${GITHUB__APP__WEBHOOK__SECRET}"
EOF

# Install RHTAP via rhtap-cli
echo "[INFO] Performing rhtap-cli installation of RHTAP"
JENKINS_API_TOKEN=$(cat /usr/local/rhtap-cli-install/jenkins-api-token)
JENKINS_URL=$(cat /usr/local/rhtap-cli-install/jenkins-url)
JENKINS_USERNAME=$(cat /usr/local/rhtap-cli-install/jenkins-username)

rhtap-cli integration jenkins --token="$JENKINS_API_TOKEN" --url="$JENKINS_URL" --username="$JENKINS_USERNAME" --force
rhtap-cli integration gitlab --token "${GITLAB__TOKEN}"
rhtap-cli deploy --timeout 25m --config ./config.yaml

# Retrieve URLs and credentials
homepage_url="https://$(kubectl -n rhtap get route backstage-developer-hub -o 'jsonpath={.spec.host}')"
callback_url="https://$(kubectl -n rhtap get route backstage-developer-hub -o 'jsonpath={.spec.host}')/api/auth/github/handler/frame"
webhook_url="https://$(kubectl -n openshift-pipelines get route pipelines-as-code-controller -o 'jsonpath={.spec.host}')"
acs_central_url="https://$(kubectl -n rhtap-acs get route central -o 'jsonpath={.spec.host}')"
acs_central_password=$(kubectl -n rhtap-acs get secret central-htpasswd -o go-template='{{index .data "password" | base64decode}}')
quay_host=$(kubectl -n rhtap-quay get route rhtap-quay-quay -o 'jsonpath={.spec.host}')
quay_username=$(kubectl -n rhtap-quay get secret rhtap-quay-super-user -o go-template='{{index .data "username" | base64decode}}')
quay_password=$(kubectl -n rhtap-quay get secret rhtap-quay-super-user -o go-template='{{index .data "password" | base64decode}}')

# Output URLs and sensitive information
echo "[INFO] homepage_url=$homepage_url"
echo "[INFO] callback_url=$callback_url"
echo "[INFO] webhook_url=$webhook_url"

# Configure Quay integration in ACS
echo "[INFO] Configuring Quay integration in ACS"
curl -k -X POST "$acs_central_url/v1/imageintegrations" -u admin:"$acs_central_password" \
  -d '{
    "id": "",
    "name": "rhtap-quay",
    "categories": ["REGISTRY"],
    "quay": {
      "endpoint": "'"${quay_host}"'",
      "oauthToken": "",
      "insecure": false,
      "registryRobotCredentials": {
        "username": "'"${quay_username}"'",
        "password": "'"${quay_password}"'"
      }
    },
    "autogenerated": false,
    "clusterId": "",
    "skipTestIntegration": true,
    "type": "quay"
  }'
