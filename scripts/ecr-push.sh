#!/usr/bin/env bash
# Authenticates with ECR, tags the local image with the current Git SHA, and pushes it.
#
# Usage:
#   ./scripts/ecr-push.sh
#
# Environment variables:
#   AWS_REGION        — AWS region (default: us-east-1)
#   TF_WORKING_DIR    — ECR Terraform module directory (default: infra/ecr)
#   LOCAL_IMAGE       — Local image name to tag and push (default: ntc-constellation-api:local)
#   GIT_SHA           — Git commit SHA to use as image tag (default: current HEAD)
#
# References:
#   AWS ECR - Pushing a Docker image
#     https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html
#   AWS CLI - ecr get-login-password
#     https://docs.aws.amazon.com/cli/latest/reference/ecr/get-login-password.html
#   Docker tag and push
#     https://docs.docker.com/reference/cli/docker/image/tag/

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
TF_WORKING_DIR="${TF_WORKING_DIR:-infra/ecr}"
LOCAL_IMAGE="${LOCAL_IMAGE:-ntc-constellation-api:local}"
GIT_SHA="${GIT_SHA:-$(git rev-parse --short HEAD)}"

REPOSITORY_URL=$(terraform -chdir="${TF_WORKING_DIR}" output -raw repository_url 2>/dev/null)

if [[ -z "${REPOSITORY_URL}" ]]; then
  echo "could not read repository_url from terraform outputs in '${TF_WORKING_DIR}'"
  exit 1
fi

aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${REPOSITORY_URL%%/*}"

docker tag "${LOCAL_IMAGE}" "${REPOSITORY_URL}:${GIT_SHA}"
docker push "${REPOSITORY_URL}:${GIT_SHA}"

echo "pushed ${REPOSITORY_URL}:${GIT_SHA}"
