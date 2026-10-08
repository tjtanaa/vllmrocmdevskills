---
name: vllm-rocm-dev-setup
description: >-
  Sets up a persistent vLLM development workspace on AMD ROCm, including the
  Docker or Podman launch script, model-weight mounts, git identity, and an
  editable vLLM install. Use when starting vLLM work on AMD GPUs, launching
  the ROCm container, choosing GFXARCH, cloning a repository into the
  workspace, rebuilding vLLM, or serving a model with vLLM on ROCm.
---

# vLLM ROCm development setup

All development, testing, and review happens inside the container started from `launchdocker.sh`. Keep code and other workspace files in `WORKSPACEPATH`. Keep model weights on the host in `MODELWEIGHTPATH`, which the launch script bind-mounts into the container.

## Determine where you are running

If the current shell is already inside the vLLM container, follow [In-container setup](#in-container-setup). Otherwise follow [Host setup](#host-setup).

## Host setup

Ask the user, in this order, and wait for the answers before creating anything:

1. **Image.** Present `vllm/vllm-openai-rocm:nightly-rocm100` as the default. Use another image only when the user overrides it.
2. **`WORKSPACEPATH`.** Host directory for the workspace and code.
3. **`MODELWEIGHTPATH`.** Host directory for model weights.
4. **`GFXARCH`.** Target GPU architecture, such as `gfx950`.
5. **Repository.** Ask which git repository to clone. Do not assume a URL.

Then:

1. Copy the workspace template (the directory that contains `launchdocker.sh`) to `WORKSPACEPATH`.
2. Copy skills into the workspace as described in [Skills](#skills).
3. Edit `WORKSPACEPATH/launchdocker.sh` as described in [Launch script](#launch-script).
4. Clone the repository the user named into `WORKSPACEPATH`.
5. Apply [Git](#git) inside that clone.
6. Start the container with the edited `launchdocker.sh` and do all further build, test, and review work inside it.

Use `docker` or `podman`, whichever is the available runtime, with the flags in `launchdocker.sh`.

## In-container setup

The image and weight mounts are already in effect. Ask only:

1. **`WORKSPACEPATH`.** Directory for the workspace and code.
2. **`GFXARCH`.** Target GPU architecture.
3. **Repository.** Ask which git repository to clone. Do not assume a URL.

Copy skills into the workspace as described in [Skills](#skills). Clone the repository the user named into `WORKSPACEPATH`, then apply [Git](#git). Store model weights in the existing `HF_HOME` and `HF_HUB_CACHE` directories. Do not start a nested container.

If multi-node RDMA is required and this container was launched without the flags in [Launch script](#launch-script), update `launchdocker.sh` and tell the user the container has to be recreated from that script before RDMA work.

## Skills

The workspace template ships `.agents/skills/`. Copying the template into `WORKSPACEPATH` brings those skills with it. Keep them.

Also merge the repository `.agents` directory (this checkout: `/home/akk/tj/vllmrocmdevskills/.agents`) into `WORKSPACEPATH/.agents`. Merge the trees so a skill that exists only in the template stays in place. Skills added later under either `workspacetemplate/.agents/skills/` or the repository `.agents/skills/` are part of that copy. Optimization work follows `vllm-rocm-optimize`. Pull-request review follows `vllm-rocm-review`.

## Launch script

`launchdocker.sh` is the source of truth for the container. Keep its existing flags. Substitute the values below.

| Placeholder | Value |
|---|---|
| Image | User's image; default `vllm/vllm-openai-rocm:nightly-rocm100` |
| Host workspace mount | `WORKSPACEPATH` mounted at `/app/workspace` |
| Host weight mounts | `MODELWEIGHTPATH` mounted at both `/app/model` and `/app/shared_vllm` |
| `HF_HOME` and `HF_HUB_CACHE` | `/app/model/huggingfacehub` |
| Container `--name` | Basename of `WORKSPACEPATH` |

When the task needs cross-node RDMA and the script is missing the required devices, capabilities, or network flags, add those flags to `launchdocker.sh`.

## Git

Inside the cloned repository only:

```bash
git config --local user.email "tunjian.tan@embeddedllm.com"
git config --local user.name "tjtanaa"
```

Leave global git config unchanged. Make commits from this clone so the user's changes stay persistent. Run pre-commit and fix failures until it passes, then commit:

```bash
git commit -s -m "message"
```

The user pushes manually. Do not push.

## vLLM server

When `GFXARCH` is `gfx942` or `gfx950`, include `VLLM_ROCM_USE_AITER=1` in the vLLM server command. For every other `GFXARCH`, leave that variable unset.

If the right server command for a model is unknown, use the matching recipe at <https://recipes.vllm.ai/>.

## Reinstall vLLM from source

Run this inside the container from the vLLM repository root so a stale build is not reused:

```bash
python3 -m pip uninstall -y vllm
rm -rf build/ && rm -rf .deps && rm -rf vllm.egg-info && rm -rf vllm/*.so
PYTORCH_ROCM_ARCH=<GFXARCH> python3 setup.py develop
```

When `csrc/` matches `vllm-project/vllm` `main`, use the precompiled build instead:

```bash
VLLM_USE_PRECOMPILED=1 PYTORCH_ROCM_ARCH=<GFXARCH> python3 setup.py develop
```
