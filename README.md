# kubernetes-conjur-demo

This repo demonstrates an app retrieving secrets from a Conjur cluster running
in Kubernetes or OpenShift. The numbered scripts perform the same steps that a user has to
go through when setting up their own applications.

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
process of configuring Conjur and deploying a test app. The test app uses the
Conjur Ruby API, configured with the access token provided by the authenticator
sidecar, to retrieve a secret value from Conjur.

You can run the `./rotate` script to rotate the secret value and then run the
final numbered script again to retrieve and print the new value.