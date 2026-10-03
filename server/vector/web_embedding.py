import torch
import mobileclip
from PIL import Image
from pathlib import Path


MODEL_NAME = "mobileclip_s0"
model, _, preprocess = mobileclip.create_model_and_transforms(MODEL_NAME, pretrained="checkpoints/mobileclip_s0.pt")
model.eval()


def extract_web_image_embedding(image_path: Path) -> list[float]:
    """
    Extracts MobileCLIP embedding vector on the server for web-uploaded images.
    """
    image = Image.open(image_path).convert("RGB")
    image_tensor = preprocess(image).unsqueeze(0)

    with torch.no_grad():
        features = model.encode_image(image_tensor)

        # Normalize features
        normalized_features = features / features.norm(dim=-1, keepdim=True)


    # Convert PyTorch Tensor to Python List
    embedding_vector = normalized_features.squeeze(0).tolist()
    return embedding_vector