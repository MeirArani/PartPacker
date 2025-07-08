#!/bin/bash

PYTHONPATH=. python vae/scripts/infer.py --ckpt_path pretrained/vae.pt --input assets/meshes/ --output_dir output/

PYTHONPATH=. python flow/scripts/infer.py --ckpt_path pretrained/flow.pt --input assets/images/ --output_dir output/

python app.py
