# kubernetes-conjur-demo

This repo demonstrates an app retrieving secrets from a Conjur cluster running
in Kubernetes or OpenShift. The numbered scripts perform the same steps that a
user has to go through when setting up their own applications.

**Note:** These demo scripts have only been tested with the following products:
  - Dynamic Access Provider v10+. Older versions of Conjur Enterprise v4 are not supported.
  - cyberark/conjur-authn-k8s-client v0.11+
  - cyberark/secretless-broker v1.0+
  - cyberark/conjur (Conjur OSS) v1.5

# Setup

### Platform

If you are working with OpenShift, you will need to begin by setting:

```
export PLATFORM=openshift
```

Otherwise, this variable will default to `kubernetes`.

### Deploying Conjur

Before running this demo you will need to set up a Conjur cluster. It is
recommended that you **set up a separate Conjur cluster** purely for the
purpose of running this demo as it loads Conjur policy that you would not
want to be present in your production environment.

There are a couple of options available for deploying a Conjur cluster:

- You can deploy a Conjur DAP cluster, including a Conjur master node
  and several Conjur follower nodes using the
  [Kubernetes Conjur deploy scripts](https://github.com/cyberark/kubernetes-conjur-deploy).
- You can deploy a Conjur OSS cluster using the  
  [Conjur OSS Helm Chart](https://github.com/cyberark/conjur-oss-helm-chart).

### Script Configuration

#### Core Configuration

You will need to provide a name for the kubernetes namespace in which your test app
will be deployed AND the database type to deploy with the app:

```
export TEST_APP_DATABASE=mysql
export TEST_APP_NAMESPACE_NAME=test-app
```
As found at boostrap.env

You will also need to set several environment variables to match the values used
when configuring your Conjur deployment. Note that if you may already have these
variables set if you used the
[Conjur deploy scripts](https://github.com/cyberark/kubernetes-conjur-deploy)
to deploy Conjur and you're using the same shell to run the Conjur demo
scripts.

```
export AUTHENTICATOR_ID=<service-id>
export CONJUR_ACCOUNT=<account-name>
export CONJUR_ADMIN_PASSWORD=<admin-password>
export CONJUR_NAMESPACE_NAME=<conjur-namespace-name>
export DOCKER_REGISTRY_URL=<registry-domain>
export DOCKER_REGISTRY_PATH=<registry-domain>/<additional-pathing>
```

#### Configuring a Master Node: Load Policy and Initialize Certificate Authority

If you are using a Conjur DAP cluster that has been deployed using the
[Kubernetes Conjur deploy scripts](https://github.com/cyberark/kubernetes-conjur-deploy),
then you'll very likely want the Kubernetes Conjur demo scripts to include
provisioning of the Conjur master with the following:

- Load Conjur authentication policies for the demo scripts.
- Initialize the Conjur Certificate Authority for signing Certificate
  Signing Requests (CSRs) from Kubernetes authentication clients.
  (Background: The Conjur Kubernetes authenticator requires that Conjur
  be configured to act as a certificate authority, so that Conjur can create
  a client certificate to establish mutual TLS with authenticator clients.)

***_Note: if you have been following the [Conjur documentation](https://docs.conjur.org/Latest/en/Content/Integrations/Kubernetes_deployConjur.htm),
you may have completed this step while you were already logged into the Conjur
master. If not, you will need to do so now._***

To enable the Kubernetes Conjur demo scripts to provision a Conjur master
as described above, export the following environment variable setting
before running the demo scripts:

  ```
  export DEPLOY_MASTER_CLUSTER=true
  ```

***_Note that when `CONJUR_OSS_HELM_INSTALLED` environment variable is set
   to `true`, then the scripts will perform the above provisioning on the
   Conjur master regardless of how the `DEPLOY_MASTER_CLUSTER envirionment
   variable is set._***

#### Configuring Applications to Use Annotation-Based Authentication

##### Background: Host-ID-Based Authentication
By default, the Kubernetes Conjur demo scripts will create Conjur
authentication policies and configure applications to use host-ID based
Kubernetes authentication". With host-ID-based Kubernetes authentication,
the Kubernetes resource that is to be used as Conjur authentication
identities are included directly in the host ID value of a Conjur
authentication policy, for example:

  ```
  - !host
    id: app-test/service_account/test-app-secretless
    annotations:
      kubernetes/authentication-container-name: secretless
      kubernetes: "true"
  ```

and the authentication container used by the application (e.g. Secretless
Broker, authen-k8s sidecar container, or authen-k8s init container)
is configured with an authentication URL that ends with a URL-encoded
version of that host ID. For example, for the policy snippet above, the
authentication URL would end with a URL-encoded version of
`app-test/service_account/test-app-secretless`.

##### The Alternative: Using Annotation-Based Authentication

Alternatively, you can configure the scripts to use
[annotation-based authentication](https://docs.conjur.org/Latest/en/Content/Integrations/Kubernetes_AppIdentity.htm).
With annotation-based Kubernetes authentication, an application name is used
as the host ID in the Conjur authentication policy, and the Kubernetes
resource(s) that is(are) to be used as Conjur authentication identities are
included as annotations. For example:

  ```
  - !host
    id: test-app-secretless
    annotations:
      authn-k8s/namespace: app-dane-test
      authn-k8s/service-account: test-app-secretless
      authn-k8s/deployment: test-app-secretless
      authn-k8s/authentication-container-name: secretless
      kubernetes: "true"
  ```

With annotation-based authentication, the application is configured with
a Conjur authentication URL that ends with the application name.

To enable annotation-based authentication, export the following environment
variable setting in the shell where you are running these demo scripts:

  ```
  export ANNOTATION_BASED_AUTHN=true
  ```

before running the Kubernetes Conjur demo scripts.

#### Using Conjur Clusters That Were Deployed via Conjur OSS Helm Chart

If you are using the Kubernetes Conjur demo scripts on a Conjur OSS cluster
that was deployed using the
[Conjur OSS Helm Chart](https://github.com/cyberark/conjur-oss-helm-chart),
then export the following environment variable before running the demos
scripts:

  ```
  export CONJUR_OSS_HELM_INSTALLED=true
  ```

Having this environment variable set to `true` causes some additional steps
to be taken to account for differences between what is set up by the
Kubernetes Conjur deploy scripts versus what is set up by the Conjur OSS
Helm Chart.

#### Deploying Applications Using NodePort Instead of LoadBalancer Services

Some Kubernetes platforms (e.g. MiniKube or Kubernetes-in-Docker) do not
provide load balancer functionality directly. While it is possible to
deploy software load balancers (e.g. MetalLB) as an add-on for these
platforms, it is often inconvenient or difficult to find a pool of
routed IP addresses with which to configure a software load balancer.

To help with this scenario, the Kubernetes Conjur demo scripts support an
environment variable setting that can be used to configure the scripts to
configure applications with NodePort type services instead of LoadBalancer
type services.

To deploy applications using `NodePort` type services, export the following
environment variable before running the Conjur Kubernetes demo scripts:

  ```
  export TEST_APP_NODEPORT_SVCS=true
  ```

#### Configuring Applications to Use Deployment Name for Authentication

If you would like your applications to use a deployment name as an
authentication identity when authenticating with Kubernetes (as opposed to
using service account name), then set the following:

```
export CONJUR_AUTHN_LOGIN_RESOURCE=deployment
```
Otherwise, this variable will default to `service_account`, and the service
account name will be used when authenticating your application with
Kubernetes.

Also, if using a private Docker registry:

```
export DOCKER_USERNAME=<your-username>
export DOCKER_PASSWORD=<your-password>
export DOCKER_EMAIL=<your-email>
```

# Usage

Once the Kubernetes Conjur demo script environment variables are configured
as described above, all that is needed to run the demo scripts is to
run the following from the root directory of this repository:

  ```
  ./start
  ```

This will progress through the numbered scripts in sequence (i.e.
./0_check_dependencies.sh, ./1_create_test_app_namespace.sh, etc.)

## Demo Applications
The test app is based on the `cyberark/demo-app` Docker image
([GitHub repo](https://github.com/conjurdemos/pet-store-demo)). It can be deployed
with a PostgreSQL or MySQL database and the DB credentials are stored in Conjur.
The app uses Summon at runtime to retrieve the credentials it needs to connect
with the DB, and it authenticates to Conjur using the access token provided by
the authenticator sidecar.

There are three iterations of this app that are deployed:
- App with sidecar authenticator client (to provide continuously refreshed Conjur access tokens)
- App with init container authenticator client (to provide a one-time Conjur access token on start)
- Secretless app with [Secretless Broker](https://github.com/cyberark/secretless-broker)
  deployed as a sidecar, managing the credential retrieval / injection for the app

## Contributing

We welcome contributions of all kinds to this repository. For instructions on how to get started and descriptions of our development workflows, please see our [contributing
guide][contrib].

[contrib]: https://github.com/cyberark/conjur/blob/master/CONTRIBUTING.md
