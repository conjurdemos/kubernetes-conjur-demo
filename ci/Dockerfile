FROM ubuntu:latest

RUN mkdir -p /src
WORKDIR /src

# Install Docker client
RUN apt-get update -y && \
    apt-get install -yq apt-transport-https ca-certificates curl gnupg2 software-properties-common wget && \
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable" && \
    apt-get update && \
    apt-get install -yq docker-ce && \
    rm -rf /var/lib/apt/lists/*

# Install kubectl CLI
ARG KUBECTL_CLI_URL
RUN wget -O /usr/local/bin/kubectl ${KUBECTL_CLI_URL:-https://storage.googleapis.com/kubernetes-release/release/v1.7.6/bin/linux/amd64/kubectl} && \
    chmod +x /usr/local/bin/kubectl

# Install OpenShift oc CLI
ARG OPENSHIFT_CLI_URL
RUN mkdir -p ocbin && \
    wget -O oc.tar.gz ${OPENSHIFT_CLI_URL:-https://github.com/openshift/origin/releases/download/v3.7.2/openshift-origin-client-tools-v3.7.2-282e43f-linux-64bit.tar.gz} && \
    tar xvf oc.tar.gz -C ocbin && \
    ls -la ocbin && \
    cp "$(find ./ocbin -name 'oc' -type f | tail -1)"  /usr/local/bin/oc  && \
    rm -rf ocbin oc.tar.gz

# Install Helm CLI
ARG HELM_CLI_VERSION
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
RUN chmod 700 get_helm.sh
RUN ./get_helm.sh --no-sudo --version ${HELM_CLI_VERSION:-v3.5.2}

# Install Google Cloud CLI
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    apt-get update -y && \
    apt-get install -yq google-cloud-sdk google-cloud-sdk-gke-gcloud-auth-plugin

# Add the WORKDIR as a safe directory so git commands
# can be run in containers using this image
RUN git config --global --add safe.directory /src
RUN git config --global --add safe.directory /src/bash-lib
