#!/bin/bash
set -eax

# shellcheck disable=SC1091
. .env

case $1 in
    "run")
        VERSION=$2
        OVERRIDE_PATH="/opt/awada/configurations/${SERVICE_NAME}.compose.override.yaml"
        envsubst < compose.yaml | docker exec -i store cp /dev/stdin "$OVERRIDE_PATH"
        docker exec store bash -c "\
           curl --location --request POST \
              'http://localhost/store/api/v1/products/${IMAGE_NAME}/local/activate/'
         "
        exit 0
        ;;
    "build")
        case $2 in
            "prod")
                target="production"
                VERSION=$3
                tags="  -t ${ALPHA_REGISTRY}/${IMAGE_NAME}:$3 \
                        -t ${ALPHA_REGISTRY}/${IMAGE_NAME}:latest \
                        --push"
                ;;
            "local")
                target="dev"
                PLATFORM="linux/amd64"
                VERSION="local"
                tags="  -t ${ALPHA_REGISTRY}/${IMAGE_NAME}:local \
                        -o type=docker"
                ;;
        esac
        ;;
    *)
        echo Неверный аргумент
        exit 1
esac

# shellcheck disable=SC2016
ENCODED_COMPOSE=$( envsubst '$IMAGE_NAME' < compose.yaml | base64 -w 0 )

# shellcheck disable=SC2086
docker buildx build \
    --platform "${PLATFORM}" \
    --target $target \
    ${tags} \
    --label SERVICE_NAME="${SERVICE_NAME}" \
    --label VERSION="${VERSION}" \
    --label DESCRIPTION="${DESCRIPTION}" \
    --label DEPENDENCIES="${DEPENDENCIES}" \
    --label GROUP="${GROUP}" \
    --label STANDALONE="${STANDALONE}" \
    --label REPLICABLE="${REPLICABLE}" \
    --label ROUTABLE="${ROUTABLE}" \
    --label ENCODED_COMPOSE="${ENCODED_COMPOSE}" \
    --build-arg DEV_REGISTRY="${DEV_REGISTRY}" \
    --build-arg PYTHON_VERSION="${PYTHON_VERSION}" \
    --build-arg NODE_VERSION="${NODE_VERSION}" \
    --pull \
    .