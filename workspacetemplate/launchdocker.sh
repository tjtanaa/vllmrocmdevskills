#!/bin/bash
docker run -it \
   --network=host \
   --ipc=host \
   --pid=host \
   --privileged \
   --cap-add=SYS_PTRACE \
   --security-opt seccomp=unconfined \
   --ulimit memlock=-1 \
   --ulimit stack=67108864 \
   --group-add=video \
   --group-add=render \
   --device /dev/kfd \
   --device /dev/dri \
   --device /dev/infiniband \
   -v /sys:/sys \
   -v /shared_vllm:/app/model \
   -v /shared_vllm:/app/shared_vllm \
   -e HF_HUB_CACHE="/app/model/huggingfacehub" \
   -e HF_HOME="/app/model/huggingfacehub" \
   -v /home/ubuntu/tj/<workspace_name>:/app/workspace \
   --name <workspace_name> \
   --entrypoint /bin/bash \
   vllm/vllm-openai-rocm:nightly-rocm100