---
name: vllm-rocm-review
description: >-
  Reviews vLLM pull requests with the vLLM reviewer standard: author
  self-review, purpose and scope, a high bar for new and shared code,
  correctness, tests, and performance and accuracy evidence. Use when
  reviewing a vLLM pull request, triaging review requests, checking a diff
  before review, requesting changes, or handing a PR to a committer.
  Reproduction and benchmarks on AMD ROCm use the workspace from
  vllm-rocm-dev-setup.
---

# vLLM ROCm review

Review a vLLM pull request with this standard. Background: RFC #58253.

Run reproduction, tests, and benchmarks inside the container from `vllm-rocm-dev-setup`. When that workspace is not ready, follow that skill first. Use its `GFXARCH`, reinstall steps, and server command. For `gfx942` and `gfx950`, server commands include `VLLM_ROCM_USE_AITER=1`. For every other `GFXARCH`, leave that variable unset. When the server command for a model is unknown, use the matching recipe at <https://recipes.vllm.ai/>.

This skill reviews a pull request. An optimization run follows `vllm-rocm-optimize`.

Read the PR with `gh` when you have the repository and number: description, linked issue or RFC, discussion, and diff. Deliver the review as GitHub-ready comments. Post them when the user asks you to submit the review. Draft Slack messages for the user to send. The user pushes. Do not push.

## Pick a PR and triage

Pick a PR you can finish. Check whether someone is already reviewing it, self-assign, and coordinate with other reviewers in #pr-reviews. Include older actionable PRs along with new submissions. Escalate questions that need a committer early.

## Require author self-review first

Every PR is reviewed by its author before review starts. The author understands and can defend every changed line, including lines written with AI assistance. A review does not replace that diligence.

When the author has not self-reviewed, stop before a technical review. Ask them to self-review and to re-request review afterward. Signs:

- the description does not match the diff
- leftover debug code, or unrelated files or changes
- an unfilled PR template
- claims with no supporting results
- the author cannot explain the code when asked

Minimum reply:

> Thanks for the contribution! Before we start reviewing, please ensure you have completed a self-review of the full diff yourself and can explain each change. Once that's done, please re-request review.

Add a sentence when reproduction steps, test commands, or results are missing.

PR descriptions stay concise enough to extract the change. When a description is too long for that — most AI-generated descriptions are — ask the author to shorten it.

## Assess the PR

Read the description, the linked issue or RFC, the discussion, and the diff. Establish:

| Question | What to establish |
|---|---|
| Purpose | What problem this solves, and for whom. For a bug fix, explicit steps that reproduce the failure on current `main`. |
| Scope | One coherent change. Unrelated refactors or formatting that hide it. Several independent changes packed together. |
| Direction | An open design question, a competing PR, or an earlier decision that bears on this one. |
| Readiness | Enough information and implementation to review meaningfully. |

Bug-fix reproduction is the exact command or script, model, configuration, and hardware, plus the observed error or wrong output. A symptom description is not enough. If the author cannot reproduce the failure on `main`, ask whether it is already fixed before reviewing further.

Settle purpose and direction before asking for large implementation work or expensive validation. Close duplicates and superseded PRs with a link to the original or the replacement. When a proposal looks out of scope, explain the concern and ask the appropriate committer whether vLLM will take on and maintain the feature before reviewing further. Apply labels accurately and make the next action clear.

A feature or optimization can look correct and still be the wrong addition. vLLM keeps a high bar for new code and complexity. The significance, and how widely the change applies to users and workloads, has to justify the new code and the edits to existing core code. Invasive changes clear a higher bar than isolated ones. When in doubt, post in #reviewers.

Split a very large PR into smaller ones when possible. A draft of the full end state may stay open as a temporary reference.

## Review

Review the approach first, then the details. Give one coherent first round. Raise acceptance issues before presentation nits. Keep later rounds to the concerns already raised, plus problems introduced by the revision.

### Keep the solution small

The implementation is the smallest maintainable solution to the stated problem. Look for:

- unnecessary abstractions
- single-use helpers that could be inlined
- duplicated logic
- speculative configurability
- broad exception handling
- unrelated cleanup
- comments that restate the code, narrate history, run long, or are wrong

A larger change can be justified. The justification is explicit.

### Shared and core files

Spend more of the review on shared execution code. An edit there reaches many deployments, stays in the tree for a long time, and is hard to remove after the feature or model that needed it is gone. Changes here stay minimal and justified. The author explains which alternatives they considered and why they rejected them. Finding the smallest change usually takes more than one attempt.

Examples under `vllm/`:

- Model runners: `v1/worker/gpu_model_runner.py`, `v1/worker/*/model_runner.py`
- Scheduler: `v1/core/sched/scheduler.py`
- KV cache: `v1/core/kv_cache_manager.py`, `v1/core/single_type_kv_cache_manager.py`

Ask why the change belongs in shared code, and whether a backend-specific path or an existing extension point is enough. Trace other callers and backends that depend on the new behavior. A bug fix that redesigns a shared interface needs a clear reason. Name configurations that can lose performance or compatibility, including ones outside the target workload.

Code for a specific or non-default feature lives in its own files, methods, or classes and is called from the core path.

### Correctness and compatibility

Trace the new behavior and its callers. Where it applies, check error paths, boundaries, resource lifetime, concurrency, and interactions with existing features. Check public behavior, configuration, defaults, and supported inputs. When an important property is still uncertain, name it and involve the committer. CI is not a substitute for that check.

### Hot-path hazards

Check per-step code even when the PR claims no performance change. On ROCm these calls still synchronize the host and the device. The `torch.cuda` names in vLLM are the names to flag.

- **New GPU syncs.** `.item()`, `.tolist()`, `.cpu()`, `torch.cuda.synchronize()`, data-dependent shapes such as `torch.nonzero()` or boolean-mask indexing, and Python control flow on GPU tensor values stall the CPU until the GPU catches up. They break CPU/GPU overlap and async scheduling.
- **Copies from unpinned CPU memory.** Host-to-device copies from pageable CPU tensors stay synchronous even with `non_blocking=True`. A CPU staging buffer copied to the GPU every step is pinned (`is_pin_memory_available()`), allocated once, and reused.
- **Many small torch ops.** Each small op launches a kernel and adds Python and dispatch overhead. A run of them on the hot path, especially outside CUDA graphs, can dominate step time. Prefer a fused or Triton kernel, or precompute on the CPU.
- **JIT kernels missing warmup.** A new CuTeDSL or TileLang kernel is registered with the JIT warmup infrastructure so it compiles during startup. Ask the author to confirm that `--jit-monitor-mode error` reports no compiles after warmup.

## Testing, performance, and accuracy

Ask for evidence in proportion to the risk. A documentation page or an error message needs none. A new kernel, or a change to a default backend, needs tests plus performance and accuracy data.

### What belongs in the description

Validation shows that this change works. It belongs in the PR description. A permanent test guards against later regressions. It belongs in the diff.

The description includes:

- **Commands and results.** Exact test commands, environment, hardware, and results. On ROCm, state `GFXARCH` and whether `VLLM_ROCM_USE_AITER` was set.
- **Bug fixes.** Reproduction that fails on current `main`, and the same steps passing with the fix.
- **Intended path.** Evidence the new path ran: a log line, the backend selected, or a configuration that forces it.
- **Coverage.** Which existing tests cover the change, and either the new tests or why none were added.

### Reviewing new tests

A permanent test earns its CI cost and runs in a CI job.

- **Bug fixes.** The regression test fails on current `main` and passes with the fix. Prefer extending an existing test, for example with a parametrization or a case.
- **New features.** Tests cover the intended behavior through public interfaces, including the main edge cases and interactions with existing features.
- **Observable behavior.** Assertions still hold after a valid refactor. An end-to-end test can do this better than a unit test that mocks or reaches into internals. Prefer no new test over an overly specific one.
- **Reuse.** Extend an existing test file, fixture, or helper when a nearby suite fits.
- **Assertions.** Check the actual result, not only that the code returned without raising.
- **Determinism.** Watch for unseeded randomness, sleep-based waits, dependence on test order, and tolerances tighter than GPU numerics. A flaky test is worse than no test.

Skip tests that mirror implementation details, rely on heavy mocking, or add a large matrix of redundant cases. When the test diff dwarfs the code change, ask whether the scope can shrink.

### When to ask for performance data

Ask when a change:

- touches a hot path, such as model runners, attention backends, sampling, or kernels
- changes defaults that affect execution, such as backend selection, compilation, or CUDA graph settings
- claims a speedup or a memory saving
- adds synchronization, allocations, or Python overhead to per-step code

### When to ask for accuracy evidence

Ask when a change can alter model outputs:

- kernels, attention backends, or quantization methods
- model implementations or weight loading
- sampling, logits processing, or speculative decoding
- dtype, precision, or numerical handling

### Good performance data

- **Same setup.** Base revision and PR revision on the same machine, with the same model, flags, and workload. On ROCm those flags include `GFXARCH` and `VLLM_ROCM_USE_AITER` as `vllm-rocm-dev-setup` requires. Published numbers, or results from a different setup, are not a baseline.
- **Commands.** Exact commands, preferably `vllm bench serve`, `vllm bench latency`, or `vllm bench throughput`. Kernel microbenchmarks live in `benchmarks/kernels/`.
- **Context.** Hardware, GPU count, parallelism, model, dtype, quantization, and the relevant configuration.
- **Metrics.** For serving: TTFT, TPOT or ITL, and throughput across several request rates or concurrency levels. For kernels: representative shapes from real models.
- **Regressions.** Include configurations that might regress, such as small batches, other backends, or other hardware.
- **Noise.** Include warmup and repeated runs when the claimed gap is small enough that variance could explain it.

A kernel microbenchmark shows that the kernel is faster in isolation. End-to-end `vllm bench` results show whether it changes latency or throughput once fused, compiled, or captured in a graph with the rest of the model. A kernel PR that claims a speedup includes those end-to-end results. Microbenchmarks support them.

### Good accuracy evidence

Match the evidence to how outputs can change.

- A refactor or plumbing change that should leave numerics alone needs greedy outputs that match the base revision on a small set of prompts.
- Kernels, quantization methods, and attention backends need a numerical comparison against a reference implementation, with stated tolerances, plus a task-level evaluation.
- A model or feature change with broader impact needs a task-level evaluation from `tests/evals/`, or an equivalent `lm-evaluation-harness` run.

Use an evaluation that can detect a regression. GSM8K is saturated for many current models and can miss a real regression. It is a quick sanity check. A passing GSM8K score alone is weak evidence when numerics can change. Prefer a stronger evaluation such as GPQA, or a long-context task such as MRCR.

Compare scores with the base revision under the same configuration. The sample has to be large enough for the difference to mean something. A small drop on a few dozen examples may be noise. A consistent drop on a full evaluation is a regression. For speculative decoding, ask for acceptance rates along with accuracy.

## Red flags

- a bug fix with no test that fails without the fix
- tests that only check that code runs, or that mock away the behavior under test
- new tests that are not wired into a CI job
- many new test files or functions for a bug an existing test could cover
- new tests with a source of non-determinism
- numbers with no baseline, or a baseline and a PR run from different configurations
- results from only the best-case configuration or shape
- kernel microbenchmarks presented without end-to-end numbers
- screenshots or summaries without the commands that produced them
- "no performance impact" on a hot-path change, with no data
- accuracy measured on a handful of prompts for a numerics-affecting change
- results from a revision that no longer matches the PR
- unrelated changes in the same PR

## Feedback

Say what has to change and why. Mark acceptance concerns apart from suggestions and personal preferences. Prefix a non-blocking comment with `nit:` or `optional:`. Use **Request changes** for a substantive concern that is still open. Use **Comment** for a question or a non-blocking suggestion. Be specific enough that the author can act without guessing.

| Instead of | Write |
|---|---|
| "Please simplify." | "This wrapper has one caller and duplicates the existing helper. Can you use that helper directly, or explain what behavior requires the wrapper?" |
| "Add tests." | "Please add a regression case for the empty input that triggers this failure, and confirm it fails without the fix." |
| "Needs perf data." | "This changes per-step input preparation in the model runner. Please compare latency and throughput against the base revision using the same workload and configuration." |
| "Unnecessary core change." | "Can this be implemented in the backend-specific path? If the shared path must change, please explain which other callers need the new behavior." |

Read the author's replies and the updated diff. Accept a sound explanation when a code change is unnecessary. Resolve a concern you raised once it is addressed. When disagreement remains, summarize the question, ask the appropriate committer to decide, and record the decision on the PR. When you step away, leave a short status so another reviewer can continue.

## Enable CI

Before triggering expensive CI, confirm the run will be useful:

- Relevant local checks or focused tests have been run where practical.
- Existing failures have been inspected.
- This revision is the one the author wants tested.

Look up the current CI commands in the vLLM document **What to Expect for the Reviews**. Use those commands. Do not invent command names.

When CI fails, decide whether the change, an existing issue, or infrastructure caused it. Ask for a fix when the change is responsible. Retry when there is a reason to expect a different result, and record that reason. Consult the CI maintainers when the cause is unclear. A green run supports the review. Understanding the change still comes from reading it.

## Hand off to a committer

Mark the PR ready for committer approval when the review is complete, the author has addressed the feedback, and the relevant validation is available. Leave a short summary on the PR: what you checked, and what remains. Draft the Slack DM or Reviewer–Committer channel note for the user to send, with the same summary.
