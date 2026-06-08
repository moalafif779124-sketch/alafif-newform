import os
import io
import base64
import json
import time
import uuid
from typing import Optional
from PIL import Image

import torch
import numpy as np
from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.responses import JSONResponse, Response

app = FastAPI(title="Alafif Virtual Try-On API")

# Global model cache (loaded once)
_model = None
_pipe = None

def load_model():
    """Load IDM-VTON model (once, cached)"""
    global _model, _pipe
    if _model is not None:
        return _model, _pipe

    print("🔄 Loading IDM-VTON model...")

    # Load from local path or hub
    from diffusers import StableDiffusionPipeline, DPMSolverMultistepScheduler

    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32

    # Load the IDM-VTON pipeline
    model_id = "yisol/IDM-VTON"
    pipe = StableDiffusionPipeline.from_pretrained(
        model_id,
        torch_dtype=dtype,
        safety_checker=None,
        requires_safety_checker=False,
    )
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config)
    pipe = pipe.to(device)

    # Enable optimizations
    if device == "cuda":
        pipe.enable_attention_slicing()
        pipe.enable_vae_slicing()

    _pipe = pipe
    print(f"✅ Model loaded on {device}")
    return _model, _pipe


@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "ok", "device": "cuda" if torch.cuda.is_available() else "cpu"}


@app.post("/tryon")
async def virtual_tryon(
    person_image: UploadFile = File(..., description="Photo of the person"),
    garment_image_url: str = Form(..., description="URL of the garment product image"),
    category: str = Form("upper_body", description="upper_body / lower_body / dresses"),
    denoising_steps: int = Form(30, ge=1, le=100),
    seed: int = Form(42),
):
    """
    Virtual try-on endpoint.
    Accepts person photo + garment image URL, returns the try-on result.
    """
    try:
        model, pipe = load_model()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Model loading failed: {str(e)}")

    try:
        # Read person image
        person_bytes = await person_image.read()
        person_img = Image.open(io.BytesIO(person_bytes)).convert("RGB")

        # Download garment image
        import requests as http_req
        resp = http_req.get(garment_image_url, timeout=30)
        garment_img = Image.open(io.BytesIO(resp.content)).convert("RGB")

        print(f"📸 Person: {person_img.size}, Garment: {garment_img.size}")

        # Resize for model input
        person_img = person_img.resize((768, 1024))
        garment_img = garment_img.resize((768, 1024))

        # Generate
        generator = torch.Generator(device="cuda" if torch.cuda.is_available() else "cpu")
        generator.manual_seed(seed)

        with torch.inference_mode():
            result = pipe(
                prompt=f"a person wearing a {category} garment",
                image=person_img,
                garment_image=garment_img,
                num_inference_steps=denoising_steps,
                generator=generator,
            )
            output_img = result.images[0]

        # Convert to base64
        buf = io.BytesIO()
        output_img.save(buf, format="PNG")
        b64 = base64.b64encode(buf.getvalue()).decode()

        return JSONResponse({
            "status": "success",
            "output": f"data:image/png;base64,{b64}",
        })

    except Exception as e:
        print(f"❌ Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
async def root():
    return {
        "name": "Alafif Virtual Try-On API",
        "endpoints": {
            "POST /tryon": "Virtual try-on (person_image file + garment_image_url + category)",
            "GET /health": "Health check",
        },
        "usage": "POST to /tryon with multipart form: person_image (file), garment_image_url (string), category (string)"
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 7860))
    uvicorn.run(app, host="0.0.0.0", port=port)
