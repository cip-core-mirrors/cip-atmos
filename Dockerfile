# Geodesic image version for target image
ARG VERSION=2.8.0
# Geodesic image version for cli build image
ARG VERSION_CLI_BUILD=0.148.0
ARG OS=alpine
ARG CLI_NAME=atmos

FROM cloudposse/geodesic:$VERSION_CLI_BUILD-$OS as cli

RUN apk add -u go variant2@cloudposse

# Configure Go
ENV GOROOT /usr/lib/go
ENV GOPATH /go
ENV PATH /go/bin:$PATH

# # Build a minimal variant binary in order to download all the required libraries and save them in a Docker layer cache
# COPY cli/build-cache /tmp
# WORKDIR /tmp/build-cache
# RUN variant2 export binary $PWD variant-echo

# Build the CLI
ARG CGO_ENABLED=1
ARG CLI_NAME=atmos
WORKDIR /usr/cli
COPY cli/ .
RUN variant2 export binary $PWD $CLI_NAME && \
    ./"$CLI_NAME" help


FROM cloudposse/geodesic:$VERSION-$OS

# Install CLI
ARG CLI_NAME
COPY --from=cli /usr/cli/$CLI_NAME /usr/local/bin/${CLI_NAME}
RUN mv /usr/local/bin/$CLI_NAME /usr/local/bin/${CLI_NAME}-0.22 && \
    echo "Runnin ${CLI_NAME}-0.22 to display help" && \
    ${CLI_NAME}-0.22 help

RUN apk upgrade && \
    rm -rf /var/cache/apk/*


# Geodesic message of the Day
ENV MOTD_URL="https://cip-core.github.io/motd/geodesic.txt"

# Some configuration options for Geodesic
ENV AWS_SAML2AWS_ENABLED=true
ENV AWS_VAULT_ENABLED=false
ENV GEODESIC_TF_PROMPT_ACTIVE=false
ENV DIRENV_ENABLED=false

ENV DOCKER_IMAGE="quay.io/cipcore/cip-atmos"
ENV DOCKER_TAG="latest"

# Geodesic banner
ENV BANNER="atmos"

# Enable advanced AWS assume role chaining for tools using AWS SDK
# https://docs.aws.amazon.com/sdk-for-go/api/aws/session/
ENV AWS_SDK_LOAD_CONFIG=1
ENV AWS_DEFAULT_REGION=eu-west-1

# Install terraform.
# Set Terraform 0.14.x as the default `terraform`. You can still use `terraform-1`
# `terraform-0.12`, `terraform-0.13` or `terraform-0.15` to be explicit when needed.
# https://github.com/Versent/saml2aws#linux
RUN apk add kubectl-1.28@cloudposse && \
    apk add -u terraform-0.13@cloudposse==0.13.7-r0 && \
    apk add saml2aws@cloudposse && \
    apk add assume-role@cloudposse && \
    apk add vendir@cloudposse && \
    apk add variant2@cloudposse && \
    apk add atmos@cloudposse && \
    apk add k9s && \
    update-alternatives --set variant /usr/share/variant/2/bin/variant

ADD https://github.com/cip-core-mirrors/vendir-generator/releases/download/1.0.3/vendir-generator-linux.tar.gz /tmp
RUN tar -xzvf /tmp/vendir-generator-linux.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/vendir-generator

#RUN sh -c "$(curl -sSL https://git.io/install-kubent)"

# Add Kubectl krew plugin manager
RUN set -x && \
    TMPDIR="$(mktemp -d)" && \
    cd $TMPDIR && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    KREW="krew-${OS}_${ARCH}" && \
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" && \
    tar zxvf "${KREW}.tar.gz" && \
    ./"${KREW}" install krew && \
    cd ${WORKSPACE_DIR} && \
    rm -rf $TMPDIR && \
    echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> /etc/profile.d/kubectl-krew.sh 

# Adding kubectl plugins not available from krew marketplace
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl-convert" && \
    install -o root -g root -m 0755 kubectl-convert /usr/local/bin/kubectl-convert

# Adding helm plugins
RUN helm plugin install https://github.com/helm/helm-mapkubeapis

# Adding velero backup tool
RUN TMPDIR="$(mktemp -d)" && \
    cd $TMPDIR && \
    curl -fsSLO "https://github.com/vmware-tanzu/velero/releases/download/v1.12.2/velero-v1.12.2-linux-amd64.tar.gz" && \
    tar zxvf "velero-v1.12.2-linux-amd64.tar.gz" --strip-components=1 && \
    mv velero /usr/local/bin && \
    cd ${WORKSPACE_DIR} && \
    rm -rf $TMPDIR

# TMP: patching syslog-ng file until it's done in upstream cloudposse's geodesic image
RUN sed -i -e 's/@version: 3.36/@version: 4.1/' /etc/syslog-ng/syslog-ng.conf

# doesn't start properly if not running as root...
#USER 1000
WORKDIR /
