# Terraform test environment using official Go image with Debian
FROM golang:1.21-bullseye

# Install system dependencies
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    wget \
    unzip \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
ENV TERRAFORM_VERSION=1.5.7
RUN wget -O terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip terraform.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform.zip && \
    terraform version

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Set working directory
WORKDIR /workspace

# Copy go module files first for better caching
COPY go.mod* go.sum* ./

# Initialize go module if needed and download dependencies
RUN if [ ! -f go.mod ]; then \
        go mod init terraform-test && \
        go mod edit -require=github.com/gruntwork-io/terratest@v0.41.24 && \
        go mod edit -require=github.com/stretchr/testify@v1.8.4; \
    fi && \
    go mod download

# Copy test runner scripts
COPY run-tests.sh /run-tests.sh
COPY run-unit-tests.sh /run-unit-tests.sh
RUN chmod +x /run-tests.sh /run-unit-tests.sh

# Copy all other files
COPY . .

# Default entrypoint
ENTRYPOINT ["/run-tests.sh"]
CMD ["Quick"]