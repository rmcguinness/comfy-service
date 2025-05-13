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


Summary of Changes and Workflow:

Project Structure:
Your Go application code (with cmd/server/main.go, internal/, comfyui/ client, go.mod, go.sum).
The Dockerfile (new one provided above).
The supervisord.conf file (newly created).
Your Terraform files (main.tf, etc.).
Build Process (Manual or CI/CD - before Terraform):
Ensure your Go application (comfyui-api-service) is in the root of the build context when Docker runs, or adjust COPY . . in the go_builder stage.
Run docker build -t YOUR_IMAGE_URL . (from the directory containing the Dockerfile, Go app source, and supervisord.conf).
Push the image: docker push YOUR_IMAGE_URL.
Terraform Variables:
Update var.container_image_url with the new image URL.
Provide values for var.go_app_google_client_id and optionally var.go_app_allowed_auth_domain.
Terraform Deployment:
terraform init
terraform plan
terraform apply
Now, Cloud Run will start your container. supervisord will then launch both your compiled Go Gin API service (listening on the SERVER_PORT, e.g., 8080, and configured to talk to http://127.0.0.1:8188) and the ComfyUI Python server (listening on 127.0.0.1:8188). Cloud Run will route external traffic to the port your Go service is listening on.
