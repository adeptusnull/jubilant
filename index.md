---
layout: default
title: Welcome to Jubilant
---

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

## Test Cases

* [test1.html](test1.html) - simple redteam test that will test security of a llm
* [test2.html](test2.html) - simple redteam test with unicode to test the security of a llm
* [test3.html](test3.html) - simple redteam test with cylic to test the security of a llm

---

## Scope

This repository focuses on **failure modes**, not convenience.

Included test cases simulate:

* Forum posts and blogs with embedded agent-targeting instructions
* Injection attempts hidden in markup, comments, and metadata
* Unicode-based attacks invisible to human reviewers
* Content designed to bypass naive filters while appearing benign

The goal is to validate that an AI system:

* Treats all fetched content as untrusted data
* Enforces strict authority boundaries
* Performs extraction before reasoning
* Neutralizes instruction-like language regardless of presentation

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
