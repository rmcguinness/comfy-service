# Comfy Service Wrapper

go get github.com/google/uuid
go get github.com/gorilla/websocket
go get github.com/stretchr/testify
go get swagger


swag init -g cmd/server/main.go -o internal/docs/         at  07:41:22 PM



# 1. Authenticate Docker with GAR (replace PROJECT_ID and REGION)
# gcloud auth configure-docker REGION-docker.pkg.dev

# 2. Build the image (replace relevant parts)
# docker build -t REGION-docker.pkg.dev/PROJECT_ID/REPOSITORY/comfyui-cloudrun:latest -f Dockerfile .

# 3. Push the image
# docker push REGION-docker.pkg.dev/PROJECT_ID/REPOSITORY/comfyui-cloudrun:latest
