---
title: PartPacker
app_file: app.py
sdk: gradio
sdk_version: 5.35.0
---

# マニュアル

本書では PartPacker サーバーの操作と、GPU・Linux 付パソコンでビルド・実行する方法を案内します。

## 必要なライブラリ

- Docker
- Nvidia Container Toolkit

## コマンド要約

(カレントディレクトリは`PartPacker`だったら)

- 起動：`sudo docker compose up`
- 停止：`sudo docker compose down`

## 概要

`PartPacker`というのは、`python`のパッケージをインストールされた`conda`の仮想環境で、`app.py`というスクリプトを利用して 使いやすい`gradio`サーバーが作られるのソフトです。

Docker の機能は`docker/`というフォルダに入っています。

他のフォルダには様々なデータが入っています。
ソフト編集の必要があれば、`app.py`、 `vae/model.py`、 `flow/model.py`のファイルはいい出発点かもしれない。

## Docker

### 起動・停止

サーバーを簡単に起動したいなら、

`sudo docker compose up`

を最上位のディレクトリ（この`README.md`のファイルを入って、`PartPacker`というディレクトリ）で入力してください。

一方ではサーバー停止の時になると、

`sudo docker compose down`

を同じところで入力してください。

### ビルド

ソースコードを編集したら、新しい Docker のイメージを作る必要があります。そうすると、

`sudo docker compose up --build`

はビルドして起動のコマンドです。`--no-start`を追加したら、起動せずにビルドだけできます。

#### Partpacker

このソフトは Docker Compose のファイル（`docker/compose.yaml`)で実行されています。

その中での`partpacker`というサービスは下記に示されています。

```yaml
partpacker:
  image: partpacker
  build:
    context: .
    dockerfile: docker/Dockerfile
    network: host
  ports:
    - "7860:7860"
  volumes:
    - ${PWD}/pretrained:/workspace/PartPacker/pretrained
    - ${PWD}/output:/workspace/PartPacker/output
  user: 0:0
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: 1
            capabilities: [gpu]
  networks:
    - partpacker
```

`deploy`という部分では GPU アクセスを設定がされます。現在、一つの GPU しか利用していませんが、`count`という引数の編集で変えます。

サーバーのデフォルト・ポート（`7860`)も公開されます。

#### Caddy

ｍ DNS を活かすために、`caddy`というネットワーキングサービスも同時に利用されています。

```yaml
caddy:
  image: caddy:latest
  restart: unless-stopped
  cap_add:
    - NET_ADMIN
  ports:
    - "80:80"
    - "443:443"
    - "443:443/udp"
  volumes:
    - ${PWD}/docker/caddy/config:/etc/caddy
    - caddy_data:/data
    - caddy_config:/config
  networks:
    - partpacker
```

上記のブンブンでネットワーキングのポートを公開し、設定ファイルを転送されています。

`Caddyfile`という設定ファイルは`docker/caddy/config/Caddyfile`に入っています。このファイルでｍ DNS を簡単に利用できます：

```caddy
{
	local_certs
}

http://noe-ai.local {
	reverse_proxy partpacker:7860
}

https://noe-ai.local {
	reverse_proxy partpacker:7860
}
```

それでローカルネットワークで`http://noe-ai.local`という URL でサーバー接続ができます。

**_注意：_** `https://`で接続すれば、セキュリティのワーニングが出るかもしれません。その時、サイト除外を追加してください（方法はブラウザによると違います）。

#### Dockerfile / `startup.sh`

`docker/Dockerfile`というファイルにはビルドのコードが入っています。ビルド完了の後で、`docker/startup.sh`というスクリプトが実行されています。つまり、サーバー起動の前にコマンド実行の必要があれば、`startup.sh`の最終行の前に追加してください。

現在の`startup.sh`は下記：

```sh
#!/bin/bash

[ ! -d "output" ] && PYTHONPATH=. python vae/scripts/infer.py --ckpt_path pretrained/vae.pt --input assets/meshes/ --output_dir output/

[ ! -d "output" ] && PYTHONPATH=. python flow/scripts/infer.py --ckpt_path pretrained/flow.pt --input assets/images/ --output_dir output/

python app.py --hostname partpacker
```

最初 2 つのコマンドでは ML の推論（inference）とトレーニングがされます。既に実行されたら（`output`というディレクトリがあれば）、省略されます。

最終行はサーバーの起動です。`--hostname`・`--port | -p`の引数で、サイトのホスト名・ポートがカスタマイズできます。最後に、`--multi`の引数で複数の GPU が利用できます。

### ネットワーキングの注意

Docker Container のネットワークは特別なイントラネットです。つまり、デフォルト設定で他の Container 以外接続できません。それで、他の Container を接続する時、Container の名をホスト名として使えられますから、`partpacker`というホスト名でも接続できます。

そのため、`Caddyfile`の`reverse_proxy partpacker:7860`コマンドで、サーバーに接続できます。

`compose.yaml`の`caddy`設定の部分には`cap_add: NET_ADMIN`の設定で、`caddy`が Docker 以外のネットワークに接続できます。つまり、`caddy`の Container を通じて、他の Container が外のネットワークに接続できます。

# Manual (English)

This document outlines the structure of this software, as well as how to build/run/deploy it on any given GPU-enabled machine.

## Requirements

- Docker
- Nvidia Container Toolkit

## TL;DR

(In the `PartPacker` directory)

- Launch: `sudo docker compose up`
- Shutdown: `sudo docker compose down`

## Overview

`PartPacker` is basically made up of a core `app.py` runner, a bunch of `python` dependencies stored in a `conda` virtual environment, and a `gradio` app for deploying itself to the web.

Docker functionality is also accessible via the `docker/` subdirectory.

Other subdirectories contain misc data related to running the software. If you need to tinker with code, the `app.py`, `vae/model.py`, and `flow/model.py` are good places to start.

## Docker

### Running

If you just need to run the server, without making any changes to the source files, then you can simply run:

`sudo docker compose up `

You can also set down the server in a similar fashion:

`sudo docker compose down`

### Building

If changes are made to the source files, a new Docker image will need to be built. You can run the build and launch using:

`sudo docker compose up --build`

You can also append `--no-start` if you would like to build the image without starting the server.

#### Partpacker

The software is run via a docker compose file located at `docker/compose.yaml`

Here's an overview of the `partpacker` service:

```yaml
partpacker:
  image: partpacker
  build:
    context: .
    dockerfile: docker/Dockerfile
    network: host
  ports:
    - "7860:7860"
  volumes:
    - ${PWD}/pretrained:/workspace/PartPacker/pretrained
    - ${PWD}/output:/workspace/PartPacker/output
  user: 0:0
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: 1
            capabilities: [gpu]
  networks:
    - partpacker
```

The `deploy` block configures GPU access. Currently only one GPU is being used, but you can scale the number up as needed via the `count` parameter.

The default port for the webserver, `7860`, is also exposed.

#### Caddy

In order to make use of simple mDNS for local routing, a `caddy` container runs alongside `partpacker`:

```yaml
caddy:
  image: caddy:latest
  restart: unless-stopped
  cap_add:
    - NET_ADMIN
  ports:
    - "80:80"
    - "443:443"
    - "443:443/udp"
  volumes:
    - ${PWD}/docker/caddy/config:/etc/caddy
    - caddy_data:/data
    - caddy_config:/config
  networks:
    - partpacker
```

This exposes some basic networking ports, as well as some directories `caddy` needs to function.

The `Caddyfile` configuration located at `docker/caddy/config/Caddyfile` uses simple routes to support mDNS:

```caddy
{
	local_certs
}

http://noe-ai.local {
	reverse_proxy partpacker:7860
}

https://noe-ai.local {
	reverse_proxy partpacker:7860
}
```

This enables local users to connect to the webserver by accessing `http://noe-ai.local`

If you connect via HTTPS you will see a security warning, which you'll need to bypass.

#### Dockerfile / `startup.sh`

The `docker/Dockerfile` contains the actual build instructions. After finishing the build, `docker/startup.sh` is executed, meaning you can place commands here to run them before the server launches.

The current startup looks like this:

```sh
#!/bin/bash

[ ! -d "output" ] && PYTHONPATH=. python vae/scripts/infer.py --ckpt_path pretrained/vae.pt --input assets/meshes/ --output_dir output/

[ ! -d "output" ] && PYTHONPATH=. python flow/scripts/infer.py --ckpt_path pretrained/flow.pt --input assets/images/ --output_dir output/

python app.py --hostname partpacker
```

The first two commands perform some inference training prior to launching the server. They are skipped if an inference `output` directory is already detected.

The final command is the actual server launch. Note the `--hostname` command, which allows you to change the hostname of the webserver. A `--port`/` -p` argument is also supplied if you'd like to change the port number. Lastly, a `--multi` argument can be used if you want to make use of multiple GPUs.

### A note on networking

Docker containers network internally--meaning they can't access the outside network by default. Containers can connect to other containers by using their container name as if it were a network hostname, which is why our hostname is set to `partpacker` (the name of our docker image) in the `app.py` launch.

This is also why caddy references `reverse_proxy partpacker:7860` in its configuration. It's telling `caddy` to redirect incoming traffic to the `partpacker` container (our partpacker server) via its preferred port (`7860`).

The `caddy` container, however, _is_ able to connect to the outside network in order to listen for incoming traffic from other machines. This is done via an option in the `compose.yaml` file:

```yaml
cap_add:
  - NET_ADMIN
```

This allows `caddy` to read and send traffic to the network outside of docker. `partpacker`, however, has no direct access to external networks--meaning it must route all of its traffic through `caddy`.

# PartPacker (Original README)

![teaser](assets/teaser.gif)

### [Project Page](https://research.nvidia.com/labs/dir/partpacker/) | [Arxiv](https://arxiv.org/abs/2506.09980) | [Models](https://huggingface.co/nvidia/PartPacker) | [Demo](https://huggingface.co/spaces/nvidia/PartPacker)

This is the official implementation of _PartPacker: Efficient Part-level 3D Object Generation via Dual Volume Packing_.

Our model performs part-level 3D object generation from single-view images.

### Installation

We rely on `torch` with CUDA installed correctly (tested with torch 2.5.1 + CUDA 12.1).

```bash
pip install -r requirements.txt

# if you prefer fixed version of dependencies:
pip install -r requirements.lock.txt

# by default we use torch's built-in attention, if you want to explicitly use flash-attn:
pip install flash-attn --no-build-isolation

# if you want to run data processing and vae inference, please install meshiki:
pip install meshiki
```

### Windows Installation

It is confirmed to work on Python 3.10, with Cuda 12.4 and Torch 2.51 with TorchVision 0.20.1.

It may work with other versions or combinations, but has been tested and confirm to work on NVidia 3090 and 4090 GPUs.

- Install Python 3.10
- Install Cuda 12.4
- Git Clone the repository
  - `git clone https://github.com/NVlabs/PartPacker`
- Create a virtual environment inside the `PartPacker` directory
- Activate the virtual environment
- Install torch for your cuda version (12.4)
  - `pip install torch==2.5.1 torchvision==0.20.1 torchaudio --index-url https://download.pytorch.org/whl/cu124`
- Install requirements
  - `pip install -r requirements.txt`

### Running the GUI

Run the app with `py app.py`

It will auto-download the needed models and give you a URL for the gradio app in the console.

![image](https://github.com/user-attachments/assets/205e1d08-fc8a-4041-9845-5a9ce9cfa5f8)

### Pretrained models

Download the pretrained models from huggingface, and put them in the `pretrained` folder.

```bash
mkdir pretrained
cd pretrained
wget https://huggingface.co/nvidia/PartPacker/resolve/main/vae.pt
wget https://huggingface.co/nvidia/PartPacker/resolve/main/flow.pt
```

### Inference

For inference, it takes ~10GB GPU memory (assuming float16).

```bash
# vae reconstruction of meshes
PYTHONPATH=. python vae/scripts/infer.py --ckpt_path pretrained/vae.pt --input assets/meshes/ --output_dir output/

# flow 3D generation from images
PYTHONPATH=. python flow/scripts/infer.py --ckpt_path pretrained/flow.pt --input assets/images/ --output_dir output/

# open local gradio app (single GPU)
python app.py

# open local gradio app with multi-GPU support
python app.py --multi
```

### Multi-GPU Support

The application supports multi-GPU inference for those who are lack of GPU memory.

- **Single GPU mode** (default): `python app.py`
- **Multi-GPU mode**: `python app.py --multi`

In multi-GPU mode:

- The flow model is placed on GPU 0
- The VAE model is placed on GPU 1 (if available)
- Automatic memory management and data transfer between GPUs
- Reduced memory pressure per GPU
- Better performance with 2 or more GPUs

If only one GPU is available, the system automatically falls back to single-GPU behavior even in multi-GPU mode.

### Data Processing

We provide a _Dual Volume Packing_ implementation to process raw glb meshes into two separate meshes as proposed in the paper.

```bash
cd data
python bipartite_contraction.py ./example_mesh.glb
# the two separate meshes will be saved in ./output
```

### Acknowledgements

This work is built on many amazing research works and open-source projects, thanks a lot to all the authors for sharing!

- [Dora](https://github.com/Seed3D/Dora)
- [Hunyuan3D-2](https://github.com/Tencent/Hunyuan3D-2)
- [Trellis](https://github.com/microsoft/TRELLIS)

## Citation

```
@article{tang2024partpacker,
  title={Efficient Part-level 3D Object Generation via Dual Volume Packing},
  author={Tang, Jiaxiang and Lu, Ruijie and Li, Zhaoshuo and Hao, Zekun and Li, Xuan and Wei, Fangyin and Song, Shuran and Zeng, Gang and Liu, Ming-Yu and Lin, Tsung-Yi},
  journal={arXiv preprint arXiv:2506.09980},
  year={2025}
}
```
