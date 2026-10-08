vLLM Reviewer Handbook
This handbook describes how reviewers and committers review vLLM pull requests. See RFC #58253 for background on the Reviewer role.
Picking a PR and triaging 
Pick a PR you can make progress on and see through. Check whether someone is already reviewing it, self-assign, and coordinate with other reviewers in #pr-reviews. Include older actionable PRs, not only new submissions. Identify questions that need a committer and escalate them early.
Require author self-review and PR description clean-up first
Every PR must be reviewed by its author before it enters review. The author should understand and be able to defend every changed line, whether they wrote it by hand or with AI assistance. Reviewer and committer time is limited, and reviews are not a substitute for the author's own diligence. We want to enforce a fairly unified and consistent rule here in order to establish a culture of self-review within the contributor community.
If it's evident that the author has not reviewed their own PR, do not start a review. Politely ask them to self-review and to re-request review once they have. Signs include:
a description that doesn't match the diff
leftover debug code or unrelated files / changes
an unfilled PR template
claims with no supporting results
code the author can't explain when asked about it
A response can be as short as:
Thanks for the contribution! Before we start reviewing, please ensure you have completed a self-review of the full diff yourself and can explain each change. Once that's done, please re-request review. <you can request missing test data here too>
PR descriptions should also be concise and easy to extract pertinent information. If you encounter overly verbose PR descriptions (most AI generated PR descriptions fall into this category) please ask the author to make the PR description more concise.
Assess the PR
Read the description, the linked issue or RFC, the existing discussion, and the diff. Establish:
Purpose: What problem does this solve, and for whom? For a bug fix, does the PR include explicit instructions to reproduce the failure on current main?
Scope: Is this one coherent change, or do unrelated refactors or formatting changes obscure it? Does it contain multiple independent/orthogonal changes?
Direction: Is there an open design question, a competing PR, or an earlier decision that bears on this one?
Readiness: Is there enough information and implementation to review meaningfully?

Bug fix PRs should include explicit reproduction instructions that trigger the failure on current main: the exact command or script, model, configuration, and hardware, along with the observed error or incorrect output. A description of the symptom alone is not enough. If the author cannot reproduce the failure on main, ask whether it has already been fixed before reviewing further.
Settle purpose and direction before requesting extensive implementation work or expensive validation. Close duplicates and superseded PRs with a link to the original or replacement. For proposals that appear out of scope, explain the concern and ask the appropriate committer whether vLLM is willing to take on and maintain the feature before reviewing further. Apply labels accurately and make the next action clear.
IMPORTANT:
You should not assume that because a particular feature or optimization looks correct/beneficial, it’s necessarily something that we would want to accept into vLLM. We have a high bar for adding new code/complexity. The significance and breadth of applicability to users / relevant workloads must justify the amount of new code and/or modifications to existing core code. The bar is higher for “invasive” changes than those which are isolated. When in doubt post in #reviewers.
Very large PRs should be broken into smaller ones whenever possible. It’s fine to keep a draft PR with the full end state as a temporary reference.
Reviewing a PR
Review the overall approach first, then the details. Give the author one coherent first round of feedback instead of introducing new requirements with every revision. Raise issues that affect acceptance before minor presentation concerns.
Keep the solution simple and scoped
Check whether the implementation is the smallest maintainable solution to the stated problem. Look for:
unnecessary abstractions
excessive single-use helpers that could be inlined
duplicated logic
speculative configurability
broad exception handling
unrelated cleanup
low-value comments that restate the code, narrate the change history, are overly verbose, or are inaccurate
A larger change may be justified, but the justification should be explicit.
Heavily scrutinize changes to core / shared files
Shared execution code deserves heavy scrutiny. A local change can affect many deployments and contributes to complexity creep. Code added here is long-lived, needs more maintenance, and is hard to remove even after the feature or model it serves is no longer widely used. Spend a larger share of your review time on these changes. Changes here should be minimal and well justified. Finding the simplest, most minimal change usually requires exploring a few options, so expect the author to explain which alternatives they considered and why they rejected them. Examples under vllm/:
Model runners: v1/worker/gpu_model_runner.py, v1/worker/*/model_runner.py
Scheduler: v1/core/sched/scheduler.py
KV cache management: v1/core/kv_cache_manager.py, v1/core/single_type_kv_cache_manager.py
Ask why the change belongs in shared code and whether a backend-specific path or an existing extension point would suffice. Trace other callers and backends that depend on the modified behavior. A bug fix that redesigns a shared interface needs a clear justification. Consider which configurations might lose performance or compatibility, even when the target workload improves.
Code which pertains to a specific/non-default feature or configuration should be isolated in its own files/methods/classes and accessed from core files/paths rather than included in the core files themselves.
Check correctness and compatibility
Trace the changed behavior and its callers. Where applicable, consider error paths, boundary conditions, resource lifetime, concurrency, and interactions with existing features. Check changes to public behavior, configuration, defaults, and supported inputs. If you cannot establish an important property, name the uncertainty and involve the appropriate committer rather than assuming CI will catch it.
Other things to look for
Look for these in per-step code, even when the PR does not claim a performance change:
New GPU syncs: .item(), .tolist(), .cpu(), torch.cuda.synchronize(), data-dependent shapes such as torch.nonzero() or boolean-mask indexing, and Python control flow on GPU tensor values all stall the CPU until the GPU catches up. These break CPU/GPU overlap and async scheduling.
Copies from unpinned CPU memory: Host-to-device copies from pageable CPU tensors are synchronous even with non_blocking=True. CPU staging buffers that are copied to the GPU every step should be pinned (see is_pin_memory_available()) and preferably allocated once and reused.
Excessive small torch ops: Each small op launches its own kernel and adds Python and dispatch overhead. Many of them on the hot path, especially outside CUDA graphs, can dominate step time. Prefer a fused or Triton kernel or precomputing on the CPU.
JIT kernels not registered for warmup: New CuTeDSL or TileLang kernels should be registered with the JIT warmup infrastructure so they compile during startup instead of on the first request that hits them. Ask the author to confirm that running with --jit-monitor-mode error reports no post-warmup compiles.
Testing, performance, and accuracy expectations
Ask for evidence in proportion to the risk. A change to a documentation page or an error message needs none. A new kernel or a change to a default backend needs tests plus both performance and accuracy data.
Testing in the PR description
Validation and permanent test coverage serve different purposes. Validation shows the change works and belongs in the PR description. A permanent test guards against future regressions and belongs in the diff. The PR description should include:
Commands and results: The exact test commands the author ran, the environment and hardware they ran on, and the results.
Bug fixes: The reproduction instructions that fail on current main, and confirmation that the same steps pass with the fix.
Intended path exercised: Evidence that the change actually ran, rather than an unchanged fallback. For example, show a log line, the backend selected, or a configuration that forces the new path.
Coverage: Which existing tests cover the change, and either the new tests added or why none were needed.
Reviewing new tests
A permanent test must earn its ongoing cost and run in a CI job. When reviewing new or modified tests, check:
Bug fixes: The regression test fails on current main and passes with the fix, ideally derived from the reproduction in the PR description. Prefer extending an existing test, for example by adding a parametrization or case, over adding many new tests.
New features: Tests cover the intended behavior through public interfaces, including the main edge cases and interactions with existing features.
Not tied to implementation details: Tests check observable behavior, not internal structure that a valid refactor would change. Sometimes an end-to-end test does this better than a unit test that mocks or reaches into internals. Prefer no new test over an overly specific one.
Prefer reuse: Tests extend existing test files, fixtures, and helpers rather than creating a new suite when a nearby one fits.
Meaningful assertions: Assertions check the actual result, not only that code ran without raising.
Deterministic: Watch for new tests that could be flaky, for example because of unseeded randomness, timing or sleep-based waits, dependence on test order, or tolerances that are too tight for GPU numerics. A flaky test is worse than no test.
Avoid requesting tests that mirror implementation details, rely on excessive mocking, or add a large matrix of redundant cases. If the test diff dwarfs the code change, ask whether the scope can be reduced.
When to ask for performance and accuracy evidence
Ask for performance data when a change:
touches a hot path, such as model runners, attention backends, sampling, or kernels
changes defaults that affect execution, such as backend selection, compilation, or CUDA graph settings
claims a speedup or memory saving
adds synchronization, allocations, or Python overhead to per-step code
Ask for accuracy evidence when a change could alter model outputs, for example:
kernels, attention backends, or quantization methods
model implementations or weight loading
sampling, logits processing, or speculative decoding
dtype, precision, or numerical handling

What good performance data looks like
Equivalent comparison: The base revision and the PR revision run on the same machine with the same model, flags, and workload. Published numbers or results from a different setup are not a baseline.
Reproducible commands: The author includes exact commands, preferably vllm bench serve, vllm bench latency, or vllm bench throughput. Kernel microbenchmarks belong in benchmarks/kernels/.
Full context: The author reports hardware, GPU count, parallelism, model, dtype, quantization, and relevant configuration.
Relevant metrics: For serving changes, look for TTFT, TPOT or ITL, and throughput across several request rates or concurrency levels. For kernels, look for representative shapes from real models, not one favorable shape.
Regressions as well as wins: Results cover configurations that might regress, such as small batches, other backends, or other hardware, not only the target workload.
Noise accounted for: Results include warmup and repeated runs when the claimed difference is small enough for variance to explain it.

Kernel microbenchmarks are not a substitute for end-to-end numbers. A microbenchmark shows that the kernel is faster in isolation. It does not show that the kernel matters for overall latency or throughput, or that it still wins once fused, compiled, or captured in CUDA graphs alongside the rest of the model. Kernel PRs that claim a performance improvement should include end-to-end vllm bench results, with microbenchmarks as supporting evidence.
What good accuracy evidence looks like
Match the evidence to how the change could affect outputs. A refactor or plumbing change that should not affect numerics only needs greedy outputs that match the base revision on a small set of prompts. Kernels, quantization methods, and attention backends need a numerical comparison against a reference implementation with stated tolerances, plus a task-level evaluation. Model or feature changes with broader impact need a task-level evaluation from tests/evals/ or an equivalent lm-evaluation-harness run.
Choose an evaluation that can actually detect a regression. GSM8K is saturated for many current models and can miss real regressions; it is fine as a quick sanity check, but a passing score alone is weak evidence for a numerics-affecting change. Prefer stronger evaluations such as GPQA, or long-context tasks such as MRCR.
Compare scores against the base revision under the same configuration. Check that the sample size is large enough for the difference to be meaningful. A small drop on a few dozen examples may be noise, while a consistent drop on a full evaluation is not. For speculative decoding, ask for acceptance rates alongside accuracy.

Red flags
a bug fix with no test that fails without the fix
tests that only check that code runs, or that mock away the behavior under test
new tests that are not wired into any CI job
many new test files or functions for a bug that an existing test could cover
new tests with possible sources of non-determinism
numbers without a baseline, or baseline and PR runs with different configurations
only the best-case configuration or shape
kernel microbenchmarks presented without end-to-end numbers
screenshots or summaries without the commands that produced them
"no performance impact" on a hot-path change without data
accuracy measured on a handful of prompts for a numerics-affecting change
results from a revision that no longer matches the PR
unrelated changes within the same PR
Give clear feedback and follow through
Explain what needs to change and why. Distinguish acceptance concerns from suggestions and personal preferences, for example by prefixing non-blocking comments with nit: or optional:. Use Request changes for substantive unresolved concerns and Comment for questions and non-blocking suggestions. Be specific enough that the author can act without guessing.

Instead of
Write
"Please simplify."
"This wrapper has one caller and duplicates the existing helper. Can you use that helper directly, or explain what behavior requires the wrapper?"
"Add tests."
"Please add a regression case for the empty input that triggers this failure, and confirm it fails without the fix."
"Needs perf data."
"This changes per-step input preparation in the model runner. Please compare latency and throughput against the base revision using the same workload and configuration."
"Unnecessary core change."
"Can this be implemented in the backend-specific path? If the shared path must change, please explain which other callers need the new behavior."


Read the author's responses and review the updated diff. Accept a sound explanation when a code change is unnecessary. Resolve concerns you raised once they are addressed. If disagreement remains, summarize the question, ask the appropriate committer to decide, and record the decision on the PR. If you need to step away, leave a short status update so another reviewer can continue.
Enable CI when the PR is ready
Before triggering expensive CI, check that the results will be useful:
Confirm the relevant local checks or focused tests have been run where practical.
Inspect existing failures.
Avoid launching runs for a revision the author is about to replace.
See What to Expect for the Reviews for the available CI commands.
When CI fails, determine whether the failure is caused by the change, an existing issue, or infrastructure. Ask for a fix when the change is responsible. Retry only when there is a reason to expect a different result, and record that reason rather than rerunning until green. Consult the CI maintainers if the cause is unclear. Passing CI supports the review but does not replace understanding the change.
Hand off to a committer
Flag a PR as ready for committer approval when your review is complete, the author has addressed your feedback, and relevant validation is available. Leave a concise summary on the PR and notify the appropriate committer via a Slack DM or the Reviewer–Committer channel. State what you checked and what remains.

