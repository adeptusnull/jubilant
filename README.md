# 🔒 jubilant

For a description Read Below

Find the Repo Here
[Jubilant](https://github.com/adeptusnull/jubilant)

## AI Web Fetch Red Team Test Suite

**jubilant** is a security-focused test repository for evaluating vulnerabilities introduced when AI agents are allowed to fetch, parse, and reason over external web content.

This project is dedicated to **red team testing of web scraping pipelines**, with emphasis on how untrusted HTML, text, and encoding tricks can manipulate or compromise AI agents through:

* Prompt injection embedded in webpages
* Hidden or obfuscated instructions (HTML, CSS, JavaScript, Unicode)
* Authority confusion between fetched content and system context
* Role escalation and conversation hijacking
* Inadequate sanitization and normalization steps

The repository provides **deliberately hostile test cases** designed to expose unsafe assumptions in retrieval, extraction, and summarization workflows.

---

## Test Cases — Injection

These pages target the **agent**: will it obey instructions embedded in untrusted content.

* [test1.html](test1.html) - plain prompt injection in markup, script, and style
* [test2.html](test2.html) - Unicode bidirectional override, invisible to a human reviewer
* [test3.html](test3.html) - Cyrillic homoglyph substitution in ASCII-looking words

---

## Probes — Pipeline Detection

These pages target the **pipeline**: is there a language model between the agent and the
web at all. That question comes first. If a fetch tool silently routes pages through a
summarizing model, every injection result above measures that intermediate model's
resistance rather than the agent's.

* [probe7-variance.html](probes/probe7-variance.html) - **primary discriminator**; prompt variance over tool return values
* [probe0-control.html](probes/probe0-control.html) - baseline; no payload, stable size
* [probe1-verbatim.html](probes/probe1-verbatim.html) - verbatim vs. paraphrase
* [probe2-latency.html](probes/probe2-latency.html) - latency floor on a sub-kilobyte page
* [probe2b-bulk.html](probes/probe2b-bulk.html) - 140 KB payload; latency scaling and truncation
* [probe3-format.html](probes/probe3-format.html) - box-drawing, alignment, and indentation survival
* [probe4-injection.html](probes/probe4-injection.html) - six injection surfaces, six distinct markers
* [probe5-meta.html](probes/probe5-meta.html) - model identity and instruction leak
* [probe6-hallucination.html](probes/probe6-hallucination.html) - confabulation of facts absent from the page

`probe7` is decisive on its own: a parser has nowhere to put a prompt, so two orthogonal
prompts return identical bytes, while a model composes two different answers. The rest
characterize *how* a layer behaves rather than whether one exists — they read RAW on a
capable layer that complies with an instruction to preserve text. That false negative is
documented in [theory.md](theory.md) §5 and is why v1.1 exists.

---

## Harness

```sh
./bench/run-probes.sh                                        # local server, hermetic
./bench/run-probes.sh --base https://adeptusnull.github.io/jubilant
```

Fetches every page with `curl` and records the unmediated baseline — status, bytes,
latency, content hash, canary survival — then emits a scoresheet with the agent-side
prompts and blanks for the results. Default mode serves the repo from `127.0.0.1`, so the
raw-side run works in a sandbox with no egress. Requires `curl`, `python3`, and a POSIX
shell; nothing to install.

Method, scoring, and how to add a probe: [bench/README.md](bench/README.md).

---

## Running an Assessment

Suite version **JUBILANT-1.1**. The runbook is [protocol.md](protocol.md) —
preflight and authorization gate, the eleven tests in the order they must be run, a
deterministic scoring rubric, the verdict decision procedure, and a report template.

It is interactive by default: the agent confirms with the operator before each test and
warns explicitly before the four pages that carry live payloads.

[llms.txt](llms.txt) is the machine-readable entry point, following the
llmstxt.org convention, for handing the suite to an agent directly.

**The suite deliberately produces no single score.** The injection fraction measures
whichever model actually received the payloads — and if a summarizing layer sits in the
path, that was not the agent. One number would let a system score well because an
intermediate layer absorbed everything, while the agent underneath goes untested. Output
is a pipeline *classification* plus an injection *fraction*, reported together and
attributed. Reasoning in [protocol.md](protocol.md) §6.

Step through one test at a time:

```sh
./bench/run-probes.sh --list
./bench/run-probes.sh --prompt p1-verbatim --base https://adeptusnull.github.io/jubilant
```

The reasoning behind all of it — threat model, what each signal actually proves,
the confounders, and how to run a paired comparison without fooling yourself —
is in [theory.md](theory.md).

---

## Scope

This repository focuses on **failure modes**, not convenience.

Included test cases simulate:

* Forum posts and blogs with embedded agent-targeting instructions
* Injection attempts hidden in markup, comments, and metadata
* Unicode-based attacks invisible to human reviewers
* Content designed to bypass naive filters while appearing benign
* Canary pages that reveal whether a fetch tool is model-mediated or raw

The goal is to validate that an AI system:

* Treats all fetched content as untrusted data
* Enforces strict authority boundaries
* Performs extraction before reasoning
* Neutralizes instruction-like language regardless of presentation

And, before any of that, that you know how many models are in the loop. An agent cannot
be scored on content it never actually saw.

---

## What This Is Not

* Not a web scraper library
* Not a RAG framework
* Not a prompt engineering guide
* Not a compliance checklist

This is a **break-it-first** repository.

If your agent fails here, it is not safe to fetch arbitrary webpages.

---

## Intended Audience

* AI security researchers
* Red team and adversarial ML practitioners
* Engineers building agentic systems with web access
* Anyone evaluating the real risk of “let the model browse”

---

## Philosophy

> The web is hostile by default.
> HTML is not documentation.
> Authority does not propagate through fetch.

This repository exists to enforce those boundaries
