# kubernetes-conjur-demo

This repo demonstrates an app retrieving secrets from a Conjur cluster running
in Kubernetes or OpenShift. The numbered scripts perform the same steps that a
user has to go through when setting up their own applications.

**Note:** These demo scripts have only been tested with Conjur v4 and v5
Enterprise. Conjur OSS is not yet supported.

# Setup

### Conjur Version

If you are working with Conjur v4, you will need to set:

```
export CONJUR_VERSION=4
```

Otherwise, this variable will default to `5`.

### Platform

If you are working with OpenShift, you will need to begin by setting:

```
export PLATFORM=openshift
```

Otherwise, this variable will default to `kubernetes`.

### Deploying Conjur

Before running this demo you will need to [set up a Conjur cluster](https://github.com/cyberark/kubernetes-conjur-deploy)
in your Kubernetes environment. It is recommended that you **set up a separate
Conjur cluster** purely for the purpose of running this demo as it loads Conjur
policy that you would not want to be present in your production environment.

### Script Configuration

You will need to provide a name for the kubernetes namespace in which your test app
will be deployed:

```
export TEST_APP_NAMESPACE_NAME=test-app
```
As found at boostrap.env

You will also need to set several environment variables to match the values used
when configuring your Conjur deployment. Note that if you may already have these
variables set if you're using the same shell to run the demo:

```
export CONJUR_NAMESPACE_NAME=<conjur-namespace-name>
export DOCKER_REGISTRY_URL=<registry-domain>
export DOCKER_REGISTRY_PATH=<registry-domain>/<additional-pathing>
export CONJUR_ACCOUNT=<account-name>
export CONJUR_ADMIN_PASSWORD=<admin-password>
export AUTHENTICATOR_ID=<service-id>
```

and optionally (if using a private Docker registry):

```
export DOCKER_USERNAME=<your-username>
export DOCKER_PASSWORD=<your-password>
export DOCKER_EMAIL=<your-email>
```

# Usage
Run `./start` to execute the numbered scripts, which will step through the
process of configuring Conjur and deploying test app(s).

## Kubernetes
The test app is based on the `cyberark/demo-app` Docker image
([GitHub repo](https://github.com/conjurdemos/pet-store-demo)). It is deployed
with a PostgreSQL database and the DB credentials are stored in Conjur.
The app uses Summon at runtime to retrieve the credentials it needs to connect
with the DB, and it authenticates to Conjur using the access token provided by
the authenticator sidecar.

There are three iterations of this app that are deployed:
- App with sidecar authenticator client (to provide continuously refreshed Conjur access tokens)
- App with init container authenticator client (to provide a one-time Conjur access token on start)
- Secretless app with [Secretless Broker](https://github.com/cyberark/secretless-broker)
  deployed as a sidecar, managing the credential retrieval / injection for the app


### Rotation
To demonstrate how the apps respond to rotation, you can run the `./rotate` script.
This script updates the variables in Conjur and then updates the password in the
pg backends, which automatically kicks off a script to close all open connections
that use the old password.

To see this in action, you can open a terminal (while still working in the same
Kubernetes context) and run:
```
secretless_url=$(kubectl describe service test-app-secretless |
    grep 'LoadBalancer Ingress' | awk '{ print $3 }'):8080

while true
do
  echo "Retrieving pets"
  curl -i $secretless_url/pets
  echo ""
  echo ""
  echo "..."
  echo ""
  sleep 3
done
```
This will continuously query the Secretless pet store application. In another terminal
run the `rotate` script. Note that as the rotate script completes, the next query
to the app has the slightest hesitation as credentials are re-retrieved and
connections to the pg backend are re-opened, but there are no errors - the app remains
available.

## OpenShift
The test app uses the Conjur Ruby API, configured with the access token provided by the authenticator
sidecar, to retrieve a secret value from Conjur.
