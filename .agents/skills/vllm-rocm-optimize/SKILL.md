---
name: vllm-rocm-optimize
description: >-
  Optimizes vLLM on AMD ROCm by sending end-to-end bottleneck work to
  Hyperloom and direct kernel or op work to GEAK, then records a case study
  and a GEAK expert skill in the vllmrocmdevskills knowledge base so later
  GEAK runs consult that base together with GEAK's own. Use when optimizing
  vLLM on AMD GPUs, finding serving bottlenecks, tuning a vLLM server,
  speeding up a kernel or op, running Hyperloom or GEAK, or writing a case
  study for a model on a GFXARCH.
---

# vLLM ROCm optimization

Run this workflow inside the container from `vllm-rocm-dev-setup`. When that workspace is not ready, follow that skill first. Review of a resulting pull request follows `vllm-rocm-review`. Start Hyperloom and GEAK only inside that container. Keep code under `WORKSPACEPATH`. Read model weights from the mounted weight path (`MODELWEIGHTPATH` on the host, `/app/model` in the container). Use the `GFXARCH` from that skill.

For `gfx942` and `gfx950`, every vLLM server command in this workflow includes `VLLM_ROCM_USE_AITER=1`. For every other `GFXARCH`, leave that variable unset. When the server command for a model is unknown, use the matching recipe at <https://recipes.vllm.ai/>.

Clone <https://github.com/AMD-AGI/Hyperloom> and <https://github.com/AMD-AGI/GEAK> into `WORKSPACEPATH` when those checkouts are absent. Follow the skills and workflows in those checkouts.

## Choose the optimizer

| Situation | Use |
|---|---|
| End-to-end bottleneck: a model, traffic shape, or serving-throughput goal | Hyperloom |
| The user asks to optimize a named kernel, op, or source file | GEAK `kernel_workflow` |

GEAK is a subset of Hyperloom. When a next step comes from a Hyperloom finding, follow the Hyperloom skills and let them decide, including any kernel work they take on. Pass those GEAK invocations the combined knowledge directory from [Combined knowledge base](#combined-knowledge-base) and set `use_expert_skills=true`.

## Hyperloom

In the Hyperloom checkout, read and follow:

- `src/hyperloom/skills/hyperloom-setup/SKILL.md` when Hyperloom is not installed in this container
- `src/hyperloom/inference_optimizer/SKILL.md` for the optimization run

Pass `--framework vllm`. Hyperloom's own default is `sglang`. Point `--model` at the weights inside the container. Pass the workload the user stated (ISL, OSL, concurrency, TP, EP, precision). Ask for any of those the user did not give, and wait for the answer.

## GEAK

Follow `kernel_workflow/README.md` in the GEAK checkout. The kernel environment (PyTorch, Triton, and the backend under test) must already build and run. GEAK does not install those toolchains.

Build the combined knowledge directory first. Pass it as `perf_knowledge_dir` and set `use_expert_skills=true`.

## Combined knowledge base

`$GEAK_HOME` is the GEAK checkout. `$VLLMROCMDEVSKILLS` is the local clone of <https://github.com/tjtanaa/vllmrocmdevskills>. Clone that repository into `WORKSPACEPATH` when the checkout is absent.

```bash
COMBINED="$WORKSPACEPATH/geak-perf-knowledge"
rm -rf "$COMBINED"
mkdir -p "$COMBINED"
cp -a "$GEAK_HOME/perf_knowledge/." "$COMBINED/"
if [ -d "$VLLMROCMDEVSKILLS/perf_knowledge" ]; then
  cp -a "$VLLMROCMDEVSKILLS/perf_knowledge/." "$COMBINED/"
fi
python3 "$COMBINED/expert_skills/_contribute/scaffold.py" --reindex
```

`scaffold.py` locates `expert_skills/` from its own path, so this command is safe from any working directory. The second copy wins on path conflicts. `--reindex` rebuilds `expert_skills/index.yaml` in `COMBINED` so GEAK's skills and this repo's skills appear in one index. Leave `COMBINED` untracked. Leave the GEAK checkout unchanged by the copy.

GEAK `perf_knowledge/` is the general AMD reference. The vllmrocmdevskills tree holds considerations and techniques specific to one `GFXARCH` and one model. Treat both as reference. Accept a change only when on-box measurement beats the baseline.

## Case studies and expert skills

When this run targets a model on a `GFXARCH` and `perf_knowledge/case_studies/by_model/` in the vllmrocmdevskills clone has no study for that pair, add one. Also add `perf_knowledge/case_studies/by_kernel/` when a kernel technique is specific to this hardware and this model. For each measured, reusable lever in that study, add a GEAK expert skill next to it. A study whose attempts all failed still gets the case study; tell the user that no expert skill was added.

On first use, create this layout in the vllmrocmdevskills clone. Store the skill files there. The GEAK checkout already supplies `_contribute/`, `index.yaml`, and `tuning/`.

```
perf_knowledge/
├── case_studies/
│   ├── README.md
│   ├── by_model/
│   └── by_kernel/
└── expert_skills/
    └── skills/
        └── <slug>/
            └── skill.md
```

Match the case-study section order in GEAK `perf_knowledge/case_studies/README.md`. Each study uses GEAK's frontmatter (`title`, `kind`, `gens`, `regimes`, `status`, `updated`, `sources`) and these sections, in order: Context, Baseline, What we tried, What worked and what did not, Final result, Lessons, Sources. `gens` includes the `GFXARCH`. Keep failed attempts. Record a number only when this run measured it (same-session comparison, stack, and date) or the source labels it vendor-reported. Add a row to `perf_knowledge/case_studies/README.md` for every new file.

Lessons are the specialized part: kernel choices, flags, tile shapes, fusion, numerics, and pitfalls that held on this `GFXARCH` and this model and are absent from GEAK's knowledge base.

Write each expert skill by following `perf_knowledge/expert_skills/_contribute/SKILL.md` in the GEAK checkout: scaffold, fill, then validate. Run those commands in `$COMBINED/expert_skills` so `perf_knowledge/index/capability_index.yaml` is visible. `--operator` must already exist in that index. Use `--scope kernel` for an isolated-kernel win and `--scope e2e` for a serving-throughput win. `--author` is the git name from `vllm-rocm-dev-setup`. `--gens` includes the `GFXARCH`. Required body sections are When to use, Mechanism, Procedure, Knobs & pitfalls, Do-no-harm notes, and Sources.

After scaffold, fill, and `--record`, copy `skills/<slug>/` from `COMBINED` into `$VLLMROCMDEVSKILLS/perf_knowledge/expert_skills/skills/<slug>/`. Leave `index.yaml` in the workspace cache; the next combine regenerates it. Leave AMD-AGI/GEAK unchanged, and do not run `_contribute/make_pr.sh`.

In the vllmrocmdevskills clone only, use the git identity from `vllm-rocm-dev-setup`, run pre-commit when the repo has it, and commit with `git commit -s`. Leave the remote unchanged.

Then tell the user:

- the paths of the new case study and expert skill
- that the commit exists only in the local clone
- that <https://github.com/tjtanaa/vllmrocmdevskills> stays unchanged until they push

The next GEAK run loads both through the combined `perf_knowledge_dir`. Register them by adding the files, not by editing this skill.
