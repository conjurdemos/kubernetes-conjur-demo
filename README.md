# kubernetes-conjur-demo

This repo demonstrates an app retrieving secrets from Conjur or a Dynamic Access
Provider (DAP) follower running in Kubernetes or OpenShift. The numbered scripts
perform the same steps that a user has to go through when setting up their own
applications.

**Note:** These demo scripts have only been tested with the following products:
  - Dynamic Access Provider v11+ or Conjur OSS v1.5+.
    - Older versions of Conjur Enterprise v4 are not supported.
  - cyberark/conjur-authn-k8s-client v0.18+
  - cyberark/secretless-broker v1.0+

This demo will:
- Create a namespace in your cluster
- Store the Conjur certificate in a ConfigMap
- Build and push demo app Docker images
- Deploy a few instances of the [pet store](https://github.com/conjurdemos/pet-store-demo/)
  demo application (including its database) set up to run with:
  - [Secretless Broker](https://github.com/cyberark/secretless-broker) sidecar
    to manage the database connection
  - [Conjur Kubernetes Authenticator Client](https://github.com/cyberark/conjur-authn-k8s-client)
    sidecar to provide the Conjur access token, and Summon to inject the database
    credentials into the app environment
  - [Conjur Kubernetes Authenticator Client](https://github.com/cyberark/conjur-authn-k8s-client)
    init container to provide the Conjur access token, and Summon to inject the database
    credentials into the app environment
- Print a summary that verifies that each pet store demo instance is up and running

The pet store demo app is based on the `cyberark/demo-app` Docker image. It can
be deployed with a PostgreSQL or MySQL database and the DB credentials are stored
in Conjur.

## Requirements

This demo works with both Conjur OSS and DAP, but the requirements vary depending
on which you are using.

To run this demo, you must load policy. You may want to **set up a separate
Conjur cluster** purely for the purpose of running this demo since you may not want
to load demo policy in your production environment.

There are a couple of options available for deploying a Conjur cluster:

- You can deploy a demo Conjur DAP cluster, including a Conjur master node
  and several Conjur follower nodes using the
  [Kubernetes Conjur deploy scripts](https://github.com/cyberark/kubernetes-conjur-deploy).
  See the [demo guide to deploying a master cluster](https://github.com/cyberark/kubernetes-conjur-deploy/blob/master/CONTRIBUTING.md#deploying-conjur-master-and-followers-test-and-demo-only)
  for more information.
- You can deploy a Conjur OSS cluster using the  
  [Conjur OSS Helm Chart](https://github.com/cyberark/conjur-oss-helm-chart).

### Requirements for Conjur OSS

Supported platforms:
- Kubernetes v1.16+

- To run this demo with Conjur OSS, you must have deployed Conjur OSS to your
  Kubernetes cluster using the [helm chart](https://github.com/cyberark/conjur-oss-helm-chart).
- You must have credentials for a Conjur user that can load policy

{TODO: are there any other post-install instructions besides what's outlined in the
general requiremetns below that we should say they must have followed before they
can start running this demo?}

### Requirements for Dynamic Access Provider

Supported platforms:
- Kubernetes v1.16+
- OpenShift 3.11

To run this demo with DAP, you must have deployed a DAP follower to your
Kubernetes cluster following the [documentation](https://docs.cyberark.com/Product-Doc/OnlineHelp/AAM-DAP/Latest/en/Content/Integrations/ConjurDeployFollowers.htm).

Before getting started, you will need to prepare DAP. This includes:
- Initializing DAP's Kubernetes authenticator certificate authority
- Loading the policies that add host identities, application secrets, and entitlements

#### Initializing the authenticator CA

In order to use DAP's Kubernetes authenticator, DAP must be configured to
act as a certificate authority so that it can create a client certificate to
establish mutual TLS with authenticator clients.

To initialize the authenticator certificate authority in your DAP cluster,
exec into the Conjur master and run:

```
chpst -u conjur \
  conjur-plugin-service possum \
  rake authn_k8s:ca_init["conjur/authn-k8s/<AUTHENTICATOR_ID>"]
````
where you replace `<AUTHENTICATOR_ID>` with the authenticator ID your application
will be using.

*Note: if you have been following the [DAP documentation](https://docs.conjur.org/Latest/en/Content/Integrations/Kubernetes_deployConjur.htm),
you may have completed this step while you were already logged into the Conjur
master. If not, you will need to do so now.*

#### Loading the Conjur policies

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
    -e TEST_APP_DATABASE=$TEST_APP_DATABASE \
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

## Usage instructions

To run this demo via the command line, ensure you are logged in to the correct
cluster. Make sure you have followed the instructions in the
[requirements](#requirements) section so that your Conjur environment is prepared.

Set the following variables in your local environment:

| Environment Variable | Definition | Example |
|--|--|--|
| `TEST_APP_NAMESPACE_NAME` | The Kubernetes namespace in which your test app will be deployed. The demo scripts create this namespace for you. | `demo-namespace` |
| `TEST_APP_DATABASE` | The type of database to run with the pet store app. Supported values are `mysql`, `mssql`, and `postgres`. | `mysql` |
| `CONJUR_ACCOUNT` | The account your Conjur / DAP cluster is configured to use. | `myConjurAccount` |
| `PLATFORM` | (Optional) Set this variable to `kubernetes` or `openshift`, depending on which type of cluster you will be running the demo in. Defaults to `kubernetes`. | `kubernetes` |
| `CONJUR_OSS_HELM_INSTALLED` | (Optional) Boolean to determine whether you are running this demo with Conjur OSS. Defaults to `false`. | `true` |
| `TEST_APP_NODEPORT_SVCS` | (Optional) Boolean to determine whether to use NodePort type service instead of LoadBalancer services. When running MiniKube or Kubernetes-in-Docker, you may want to set this to `true`. Defaults to `false`. | `true` |
| `CONJUR_AUTHN_LOGIN_RESOURCE` | (Optional) Type of Kubernetes resource to use as Conjur [application identity](https://docs.cyberark.com/Product-Doc/OnlineHelp/AAM-DAP/Latest/en/Content/Integrations/Kubernetes_AppIdentity.htm). Defaults to `service_account`; accepts `service_account` or `deployment`. | `deployment` |

The demo scripts determine whether to use the `kubectl` or `oc` CLI
based on your `PLATFORM` environment variable configuration.

**Note**: if you are using a private Docker registry, you will also need to set:
```
export DOCKER_USERNAME=<your-username>
export DOCKER_PASSWORD=<your-password>
export DOCKER_EMAIL=<your-email>
```

Once you have:
- Reviewed the [requirements](#requirements) to ensure your Conjur / DAP server is set up correctly
- Logged into your Kubernetes cluster via the local command line
- Set your local environment as defined above

Run `./start` from the root directory of this repository to execute the numbered
scripts and step through the process of deploying test apps.

## Contributing

We welcome contributions of all kinds to this repository. For instructions on how to get started and descriptions of our development workflows, please see our [contributing
guide][contrib].

[contrib]: https://github.com/cyberark/conjur/blob/master/CONTRIBUTING.md
