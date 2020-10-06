# Contributing

For general contribution and community guidelines, please see the [community repo](https://github.com/cyberark/community).

## Contributing

1. [Fork the project](https://help.github.com/en/github/getting-started-with-github/fork-a-repo)
2. [Clone your fork](https://help.github.com/en/github/creating-cloning-and-archiving-repositories/cloning-a-repository)
3. Make local changes to your fork by editing files
3. [Commit your changes](https://help.github.com/en/github/managing-files-in-a-repository/adding-a-file-to-a-repository-using-the-command-line)
4. [Push your local changes to the remote server](https://help.github.com/en/github/using-git/pushing-commits-to-a-remote-repository)
5. [Create new Pull Request](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request-from-a-fork)

From here your pull request will be reviewed and once you've responded to all
feedback it will be merged into the project. Congratulations, you're a
contributor!

## Development

If you are using this repository for development
purposes, there is some additional functionality that
you may find useful.

- Setting the `LOCAL_AUTHENTICATOR` environment
  variable to `true` will push
  the Conjur K8s authenticator client and Secretless
  Broker from your local Docker registry to the
  remote registry (if used), and will use that image
  rather than the image from DockerHub.

  This can be useful if you are working on changes to the
  [authenticator client](https://github.com/cyberark/conjur-authn-k8s-client) and
  [Secretless Broker](https://github.com/cyberark/secretless-broker).
  - Run `./bin/build` in `conjur-authn-k8s-client` to
    generate a local Docker image `conjur-authn-k8s-client:dev`
  - Run `./bin/build` in `secretless-broker` to
    generate a local Docker image `secretless-broker:latest`
  - Set `LOCAL_AUTHENTICATOR=true`
  - Run the `./start` script in this repo as usual,
    and the demo apps will be deployed with your
    local builds of the authenticator and Secretless.

- The `ANNOTATION_BASED_AUTHN` environment variable enables you to toggle whether
  your deployment uses annotation-configured host identities or if the authentication
  type is defined in the identity path.
