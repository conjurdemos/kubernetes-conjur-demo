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

Before getting started, you will need to prepare Conjur. This includes:
- Initializing Conjur's Kubernetes authenticator certificate authority
- Loading the Conjur policies that add host identities, application secrets,
  and entitlements

## Initializing the authenticator CA

In order to use Conjur's Kubernetes authenticator, Conjur must be configured to
act as a certificate authority so that it can create a client certificate to
establish mutual TLS with authenticator clients.

To initialize the authenticator certificate authority in your Conjur cluster,
exec into the Conjur master and run:

```
chpst -u conjur \
  conjur-plugin-service possum \
  rake authn_k8s:ca_init["conjur/authn-k8s/<AUTHENTICATOR_ID>"]
````
where you replace `<AUTHENTICATOR_ID>` with the authenticator ID your application
will be using.

*Note: if you have been following the [Conjur documentation](https://docs.conjur.org/Latest/en/Content/Integrations/Kubernetes_deployConjur.htm),
you may have completed this step while you were already logged into the Conjur
master. If not, you will need to do so now.*


## Loading the Conjur policies

To generate the Conjur policies, you can run `./2_load_conjur_policies.sh`. Running
this script will also auto-generate a random database password that you will have to
load into your Conjur variables, and it will echo this password to the screen as
```
Added DB password value: 4664ab5bb33cee15336868ed
```
Once you've run this script and generated the policy files, you can run a Conjur CLI container and load the
policies in your Conjur master. Make sure that you correctly pass the DB
password to the Docker container as demonstrated below, and update the command
below with the URL of your Conjur master instance.

```
# replace the password value with your DB's password
$ db_password=4664ab5bb33cee15336868ed
$ docker run \
    --rm -it \
    -v $PWD/policy:/policy \
    -e DB_PASSWORD=$db_password \
    -e CONJUR_APPLIANCE_URL=<URL of your Conjur master> \
    -e CONJUR_ACCOUNT=$CONJUR_ACCOUNT \
    -e CONJUR_AUTHN_LOGIN="admin" \
    -e CONJUR_ADMIN_PASSWORD=$CONJUR_ADMIN_PASSWORD \
    -e CONJUR_VERSION=$CONJUR_VERSION \
    -e TEST_APP_NAMESPACE_NAME=$TEST_APP_NAMESPACE_NAME \
    cyberark/conjur-cli:5

root@0b86d4e8d4e7:/# ./policy/load_policies.sh

SHA1 Fingerprint=C4:95:D4:F2:5C:06:7F:79:E5:0D:BF:AD:92:3C:40:28:32:F8:66:C4

Please verify this certificate on the appliance using command:
              openssl x509 -fingerprint -noout -in ~conjur/etc/ssl/conjur.pem

Trust this certificate (yes/no): yes
Wrote certificate to /root/conjur-example.pem
Wrote configuration to /root/.conjurrc
Logged in
Loaded policy 'root'
...
Loading secret values for test-summon-init-app
Value added
Value added
Value added
Loading secret values for test-summon-sidecar-app
Value added
Value added
Value added
Loading secret values for test-secretless-app
Value added
Value added
Value added

root@0b86d4e8d4e7:/# exit
```

After loading the policies, run `./start` to execute the numbered scripts,
which will step through the process of deploying test apps.

#### Optional master cluster in Kubernetes (*Test and Demo Only*)
If you're running the scripts in this repo after deploying a Conjur cluster to
Kubernetes using the scripts in [`kubernetes-conjur-deploy`](https://github.com/cyberark/kubernetes-conjur-deploy)
with `DEPLOY_MASTER_CLUSTER=true` set, you can just run `./start` to deploy your
demo apps.

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

# Development

If you are using this repository for development purposes, there is some
additional functionality that you may find useful.

- Setting the `LOCAL_AUTHENTICATOR` environment variable to `true` will push
  the Conjur K8s authenticator client from your local Docker registry to the
  remote registry (if used), and will use that image rather than the image
  stored in DockerHub.
  This can be useful if you are working on changes to the [authenticator client](https://github.com/cyberark/conjur-authn-k8s-client).
  If you run `./bin/build` in that project to generate a local Docker image
  `conjur-authn-k8s-client:dev` and set `LOCAL_AUTHENTICATOR=true`, then when
  you run the `./start` script in this repo the demo apps will be deployed with
  your local build of the authenticator.
