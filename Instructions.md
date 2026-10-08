# 1 Environment Setup

## 1.1 You are calling and agent outside of a container (docker/podman)

- Ask user which docker image should you use. The default option that you present to the user should be : `vllm/vllm-openai-rocm:nightly-rocm100` unless the user wants to override it.

- Ask users where should you store the workspace , denote as WORKSPACEPATH (where the code is placed), where should you store the model weights, MODELWEIGHTPATH.

- Ask the user what is the GPU arch you are should be targeting, denote as GFXARCH.

- Next, clone the ./workspacetemplate as a template to create the base workspace to the path that the user specified. 

- feel free to git clone the repository to this new workspace, so that the code changes is persistent and I will push them manually, always make sure it pass precommit and also push commit with git -m -s "message" 
The following is my info

```
   git config --local user.email "tunjian.tan@embeddedllm.com"
   git config --local user.name "tjtanaa"
```

You must keep all the files and data here in the specified workspace, WORKSPACEPATH, and model weights in MODELWEIGHTPATH
 
The models path are also set to MODELWEIGHTPATH as written in @launchdocker.sh 
 
All development and testing and reviews has to be done in a docker container which is launch using the command in launchdocker.sh 

Most of the command in launchdocker.sh is what you need. If there are missing flags for crossnode RDMA feel free to update the command. 
 
Since you are on AMD environment gfx950, the command that we would like to use to launch the vllm server should have include `VLLM_ROCM_USE_AITER=1` . 
 
Instruction to Reinstalling vLLM prerequisite to avoid loading cached results: 
 
``` 
python3 -m pip uninstall -y vllm 
rm -rf build/ && rm -rf .deps && rm -rf vllm.egg-info && rm -rf vllm/*.so 
PYTORCH_ROCM_ARCH=<GFXARCH> python3 setup.py develop 
# PYTORCH_ROCM_ARCH=gfx1151 python3 setup.py develop 
``` 
 
If there is no change in csrc/ as compare to the github vllm-project/vllm main, we can just use `VLLM_USE_PRECOMPILED=1 PYTORCH_ROCM_ARCH=<GFXARCH> python3 setup.py develop` 
 
if you do not know what command to run for a model, you can try to refer to https://recipes.vllm.ai/ 


# 1.2 If you are already in the docker container (docker/podman)

- Ask users where should you store the workspace , denote as WORKSPACEPATH (where the code is placed).

- Ask the user what is the GPU arch you are should be targeting, denote as GFXARCH.

- feel free to git clone the repository to this new workspace, so that the code changes is persistent and I will push them manually, always make sure it pass precommit and also push commit with git -m -s "message" 
The following is my info

git config --local user.email "tunjian.tan@embeddedllm.com"
git config --local user.name "tjtanaa"
 
You must keep all the files and data here in the specified workspace, WORKSPACEPATH, and model weights in HF_HOME and HF_HUB_CACHE
 
All development and testing and reviews has to be done in a docker container which is launch using the command in launchdocker.sh 

Most of the command in launchdocker.sh is what you need. If there are missing flags for crossnode RDMA feel free to update the command. 
 
Since you are on AMD environment gfx942,gfx950, the command that we would like to use to launch the vllm server should have include `VLLM_ROCM_USE_AITER=1` .  (Do not set this variable if you are on other gfx)
 
Instruction to Reinstalling vLLM prerequisite to avoid loading cached results: 
 
``` 
python3 -m pip uninstall -y vllm 
rm -rf build/ && rm -rf .deps && rm -rf vllm.egg-info && rm -rf vllm/*.so 
PYTORCH_ROCM_ARCH=<GFXARCH> python3 setup.py develop 
# PYTORCH_ROCM_ARCH=gfx1151 python3 setup.py develop 
``` 
 
If there is no change in csrc/ as compare to the github vllm-project/vllm main, we can just use `VLLM_USE_PRECOMPILED=1 PYTORCH_ROCM_ARCH=<GFXARCH> python3 setup.py develop` 
 
if you do not know what command to run for a model, you can try to refer to https://recipes.vllm.ai/ 


