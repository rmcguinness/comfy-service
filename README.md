# Comfy Service Wrapper

A simplified wrapper around the ComfyUI WebSocket interfaces.

## Prerequisite  

1. Install Comfy UI
    1. `mkdir -p Projects`
    2. `cd Projects`
    3. `git clone git@github.com:comfyanonymous/ComfyUI.git`
    4. `cd ComfyUI`
    5. `python3 -m venv .venv`
    6. `source .venv/bin/activate`
    7. `pip install -r requirements.txt`
    8. Download a model (checkpoint)9https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5/blob/main/v1-5-pruned-emaonly.safetensors] and put in the `models/checkpoints` directory in your ComfyUI home. 
    9. Start ComfyUI `python main.py`

> NOTE: If you're on a Mac, you'll need to install Python 3.11 and ensure you're executing the python3 from the 3.11 home.
> `/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 -m venv .venv`

### Create a .env file

```conf
COMFYUI_BASE_URL=http://localhost:8188
GOOGLE_CLIENT_ID=**insert your client id here**
ALLOWED_AUTH_DOMAIN=localhost:8080
```

## Build

```shell
# From the project root
go build ./...

# Run the API
go run ./cmd/server/main.go
```

## Generate the Swagger documentation
```shell
# Generate the Swagger documentation.
swag init -g cmd/server/main.go -o internal/docs/

```

## Publish the Docker Image on GCR

```shell
# 1. Authenticate Docker with GAR (replace PROJECT_ID and REGION)
gcloud auth configure-docker REGION-docker.pkg.dev

# 2. Build the image (replace relevant parts)
docker build -t REGION-docker.pkg.dev/PROJECT_ID/REPOSITORY/comfyui-cloudrun:latest -f Dockerfile .

# 3. Push the image
docker push REGION-docker.pkg.dev/PROJECT_ID/REPOSITORY/comfyui-cloudrun:latest
```

## Using Terraform

```shell
cd terraform
terraform init
terraform plan
terraform apply
```

## Example Prompt

```json
{ "prompt": {
  "3": {
    "inputs": {
      "seed": 780438972461674,
      "steps": 20,
      "cfg": 8,
      "sampler_name": "euler",
      "scheduler": "normal",
      "denoise": 1,
      "model": [
        "4",
        0
      ],
      "positive": [
        "6",
        0
      ],
      "negative": [
        "7",
        0
      ],
      "latent_image": [
        "5",
        0
      ]
    },
    "class_type": "KSampler",
    "_meta": {
      "title": "KSampler"
    }
  },
  "4": {
    "inputs": {
      "ckpt_name": "v1-5-pruned-emaonly-fp16.safetensors"
    },
    "class_type": "CheckpointLoaderSimple",
    "_meta": {
      "title": "Load Checkpoint"
    }
  },
  "5": {
    "inputs": {
      "width": 512,
      "height": 512,
      "batch_size": 1
    },
    "class_type": "EmptyLatentImage",
    "_meta": {
      "title": "Empty Latent Image"
    }
  },
  "6": {
    "inputs": {
      "text": "beautiful scenery nature glass bottle landscape, , purple galaxy bottle,",
      "clip": [
        "4",
        1
      ]
    },
    "class_type": "CLIPTextEncode",
    "_meta": {
      "title": "CLIP Text Encode (Prompt)"
    }
  },
  "7": {
    "inputs": {
      "text": "text, watermark",
      "clip": [
        "4",
        1
      ]
    },
    "class_type": "CLIPTextEncode",
    "_meta": {
      "title": "CLIP Text Encode (Prompt)"
    }
  },
  "8": {
    "inputs": {
      "samples": [
        "3",
        0
      ],
      "vae": [
        "4",
        2
      ]
    },
    "class_type": "VAEDecode",
    "_meta": {
      "title": "VAE Decode"
    }
  },
  "9": {
    "inputs": {
      "filename_prefix": "ComfyUI",
      "images": [
        "8",
        0
      ]
    },
    "class_type": "SaveImage",
    "_meta": {
      "title": "Save Image"
    }
  }
}
}
```