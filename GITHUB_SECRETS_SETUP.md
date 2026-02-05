# GitHub Secrets Setup Guide

To deploy to your OpenShift cluster, you need to configure the following secret in your GitHub repository:

## Step 1: Add the OpenShift Token Secret

1. Go to your GitHub repository: `https://github.com/pokam1988/opentelemetry-observability`
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Create a new secret with the following details:

   **Secret Name:** `OPENSHIFT_TOKEN`
   
   **Secret Value:** (Your OpenShift token from the curl command)
   ```
   sha256~2CyAf2WU7C1zbhP2x5ifw_fy960A-i-SThbCx-fsPwE
   ```

## Step 2: Verify the Configuration

The workflow file `.github/workflows/deploy-openshift.yml` is already configured with:

- **OpenShift Server:** `https://api.rm1.0a51.p1.openshiftapps.com:6443`
- **OpenShift Namespace:** `pokamr-dev`
- **App Name:** `otel-demo`

The workflow will use the `OPENSHIFT_TOKEN` secret you just created to authenticate with your OpenShift cluster.

## Step 3: Trigger the Workflow

Once the secret is configured, you can trigger the deployment by:
- Pushing to the `main` branch
- Creating a pull request to `main`
- Manually triggering via **Actions** → **Deploy OpenTelemetry Demo to OpenShift** → **Run workflow**

## Workflow Steps

The deployment workflow includes:
1. **Validate** - Lints and validates Helm charts
2. **Security** - Runs Trivy vulnerability scanner
3. **Deploy with Helm** - Deploys the OpenTelemetry Demo to your `pokamr-dev` namespace
4. **Cleanup** - Cleans up PR environments when PRs are closed
5. **Notify** - Sends deployment status notifications

## Troubleshooting

If you encounter permission errors:
- Verify the token is valid and has the necessary permissions in your OpenShift cluster
- Check that the user associated with the token has access to the `pokamr-dev` namespace
- Ensure the token hasn't expired
