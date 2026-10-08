# 1 AMD Optimization skills

- There is a amd skills known as [hyperloom](https://github.com/AMD-AGI/Hyperloom). Use the skills there to optimize vLLM given a task.
- If there is a specific kernels or ops that user is targetting, you can use skills [GEAK](https://github.com/AMD-AGI/GEAK).

- If you are working on a new case studies for new hardware of a model, you should follow the structure in [GEAK](https://github.com/AMD-AGI/GEAK), create a new knowledge base in this repo https://github.com/tjtanaa/vllmrocmdevskills . and update the optimization skills to teach GEAK to combine both GEAK knowledge base and knowledge base from repo https://github.com/tjtanaa/vllmrocmdevskills to perform optimization. The intention is that slowly build a new specialize kernel optimization considerations and techniques that are exclusive to a hardware and to a model. Notify the user that they have new knowledge base created and has to update repo https://github.com/tjtanaa/vllmrocmdevskills .