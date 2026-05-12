[English](README.md) | 한국어

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-green.svg"></a>
  <img alt="Claude Code" src="https://img.shields.io/badge/Claude%20Code-compatible-blueviolet">
  <img alt="Foundation" src="https://img.shields.io/badge/scope-foundation%20cut-orange">
  <img alt="Deps" src="https://img.shields.io/badge/python-stdlib%20only-blue">
</p>

# claude-harness

이식 가능한 Claude Code harness. subagent · skill · hook · rule, 그리고 *왜 이렇게 설계했는지*를 설명하는 메서드로지 docs까지 한 묶음. 실제 운영 중인 autonomous engineering 프로젝트에서 추출했다.

LLM 코딩 에이전트는 *그럴듯한* 답을 낸다. *정확한* 답이 아니라. 이 harness를 빈 repo에 떨어뜨리면 자주 일어나는 사고들에 가드레일이 생긴다 — 조용한 over-engineering, 검증 없이 "다 됐다" 선언, 압박받으면 `--force` 박기, 시간이 지나며 코드가 자기 규칙을 어기는 drift.

두 레이어로 구성:

- **`.claude/`** — Claude Code가 세션 시작 시 자동으로 로드하는 실제 컴포넌트 (subagent / skill / hook / rule).
- **[`docs/harness/`](./docs/harness/)** — 그 컴포넌트들의 *근거*. 원칙, doc-pattern matrix, PRD+SPEC 쌍. wiring이 "무엇"이라면 이쪽은 "왜".

두 레이어 모두 작고 조합 가능하다. 일부만 떼어 가져가도 동작한다.

## Quickstart

> `junhjang` 부분은 본인 GitHub 핸들로 교체.

```bash
git clone https://github.com/junhjang/claude-harness.git target-dir
# 또는 기존 repo에 일부만 복사:
cp -R claude-harness/.claude claude-harness/CLAUDE.md path/to/your/repo/
cp -R claude-harness/scripts path/to/your/repo/         # /audit-docs + /audit-harness-coverage 사용 시
```

Claude Code가 세션 시작 시 `.claude/settings.json`을 자동으로 읽는다 — hook 등록, slash 라우팅, `CLAUDE.md` 로드 전부 자동이다.

세션에서 바로:

```
/audit-harness-coverage    # harness 설치 상태 검증 (~1초)
/audit-docs                # docs/ drift 점검 (~2초)
/grill-me                  # Socratic 인터뷰 skill 시연
```

기본값은 Rust + Python 스택. 다른 언어는 [`SETUP.md`](SETUP.md) 참고. hook이 예상치 못하게 막으면 [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

## 작동 방식

전제: LLM은 *정확한* 답보다 *그럴듯한* 답을 먼저 내놓는다. 다섯 가지 primitive (hook · cron · subagent · skill · slash command)를 closed loop로 엮어 흔한 실패를 잡는다.

1. **세션 시작.** SessionStart hook이 skill 인덱스를 주입하고, 최근 audit 이후 `docs/`가 변경됐으면 nudge한다.
2. **코드 요청.** `/grill-me`, `/grill-with-docs`가 모델이 잘못 해석하기 전에 모호한 지점을 드러낸다.
3. **모델이 코드 작성.** `Write|Edit` 시점에 hook이 특정 패턴을 차단한다 — tracked path의 secret 작성, 테스트 없이 source 작성 등.
4. **모델이 "done" 선언.** `/verification-before-completion` + `validator` subagent가 실제로 테스트가 실행됐고 변경된 path를 커버했는지 검증한다.
5. **PR 생성.** `pr-create-gate`가 `/review-changes`로 현재 SHA에 대한 per-file 리뷰어(`code-reviewer` / `security-reviewer` / `doc-reviewer`)를 돌릴 때까지 `gh pr create`를 막는다.
6. **Docs drift.** 일일 `/audit-docs` cron이 dead link, 썩은 frontmatter, 인덱스 누락, ADR 번호 공백을 잡는다 — deterministic, $0, LLM 호출 없음.
7. **Harness 자체의 drift.** `/audit-harness-coverage`가 `docs/harness/components/`에서 약속한 컴포넌트가 실제로 `.claude/`에 wired되어 있는지 확인한다.

3 · 5 · 6번이 핵심이다. 모델의 산문이 아무리 설득력 있어도 패턴 자체를 차단하는 deterministic 가드다.

## 어떤 실패를 막나

| 실패 | 막는 컴포넌트 |
|---|---|
| 검증 없이 "끝났다" 선언 | [`/verification-before-completion`](./.claude/skills/verification-before-completion/SKILL.md), [`tdd-check`](./.claude/hooks/tdd-check.sh), [`validator`](./.claude/agents/validator.md) |
| 사람과 에이전트가 다른 그림을 그림 | [`/grill-me`](./.claude/skills/grill-me/SKILL.md), [`/grill-with-docs`](./.claude/skills/grill-with-docs/SKILL.md) |
| 막히면 `--force`로 우회 | [`secret-guard`](./.claude/hooks/secret-guard.sh), [`pr-create-gate`](./.claude/hooks/pr-create-gate.sh), `settings.json` deny 리스트 |
| 주변 코드 안 읽고 편집 | `CLAUDE.md` §3, [`explore`](./.claude/agents/explore.md), [`tracer`](./.claude/agents/tracer.md), [`localizer`](./.claude/agents/localizer.md) |
| 코드가 자기 규칙을 어김 | [`/audit-docs`](./.claude/skills/audit-docs/SKILL.md), [`/audit-docs-semantic`](./.claude/skills/audit-docs-semantic/SKILL.md), [`/audit-harness-coverage`](./.claude/skills/audit-harness-coverage/SKILL.md), `rule-stub-check` |
| Subagent 컨텍스트가 서로 오염됨 | [`.claude/agents/`](./.claude/agents/) — 각자 fresh context window를 가진 single-contract 전문가 |
| 모델이 알면서도 반복하는 안티패턴 | [`rules/rust-llm-failures.md`](./.claude/rules/rust-llm-failures.md), [`rules/python-llm-failures.md`](./.claude/rules/python-llm-failures.md) |

## Reference

<details>
<summary><b>Subagents</b> — 11 single-contract specialists (펼치기)</summary>

한 가지 역할만 수행하는 전문가. `Agent` 도구에 해당 `subagent_type`을 넘겨 호출한다.

- **[code-reviewer](./.claude/agents/code-reviewer.md)** — PR 리뷰 (correctness · style · invariant).
- **[critic](./.claude/agents/critic.md)** — 영향이 큰 변경에 대한 원칙 단위 적대적 리뷰.
- **[security-reviewer](./.claude/agents/security-reviewer.md)** — auth · credential · secret · fail-closed 점검.
- **[test-engineer](./.claude/agents/test-engineer.md)** — unit · integration · property 테스트 작성 및 coverage 검증.
- **[validator](./.claude/agents/validator.md)** — "done" 선언 전 test / compile / new-test 게이트.
- **[doc-reviewer](./.claude/agents/doc-reviewer.md)** — 단일 doc semantic 리뷰.
- **[document-specialist](./.claude/agents/document-specialist.md)** — 외부 문서 수집 및 정리.
- **[explore](./.claude/agents/explore.md)** — read-only 코드 · 심볼 · reference finder.
- **[tracer](./.claude/agents/tracer.md)** — 파일 간 데이터 · 제어 흐름 추적.
- **[localizer](./.claude/agents/localizer.md)** — 에러 variant나 심볼의 정확한 라인 위치 파악.
- **[pr-author](./.claude/agents/pr-author.md)** — PR 생성 및 업데이트.

</details>

<details>
<summary><b>Skills</b> — 18 slash-invocable workflows (펼치기)</summary>

Slash로 호출하는 워크플로.

- **[/audit-docs](./.claude/skills/audit-docs/SKILL.md)** — deterministic docs audit (frontmatter · dead link · 인덱스 drift).
- **[/audit-docs-semantic](./.claude/skills/audit-docs-semantic/SKILL.md)** — semantic docs audit fan-out.
- **[/audit-harness-coverage](./.claude/skills/audit-harness-coverage/SKILL.md)** — harness 컴포넌트가 약속한 coverage를 만족하는지 검증.
- **[/budget-status](./.claude/skills/budget-status/SKILL.md)** — 세션 token 사용량 보고.
- **[/caveman](./.claude/skills/caveman/SKILL.md)** — 막혔을 때 문제를 가장 raw한 형태로 압축.
- **[/configuration](./.claude/skills/configuration/SKILL.md)** — config 디시플린 (schema validation · layered override · hot-reload).
- **[/critic-review](./.claude/skills/critic-review/SKILL.md)** — 원칙 단위 적대적 리뷰.
- **[/doc-pattern](./.claude/skills/doc-pattern/SKILL.md)** — 어떤 doc 타입을 쓸지 결정 (PRD / RFC / ADR / SPEC / TDD / AUDIT / POSTMORTEM / README).
- **[/error-taxonomy](./.claude/skills/error-taxonomy/SKILL.md)** — 새 에러 variant 추가 또는 레이어 간 에러 path 연결.
- **[/grill-me](./.claude/skills/grill-me/SKILL.md)** — Socratic 질문으로 숨은 가정을 끄집어내기.
- **[/grill-with-docs](./.claude/skills/grill-with-docs/SKILL.md)** — `CONTEXT.md` + ADR 기반 design 인터뷰.
- **[/new-doc](./.claude/skills/new-doc/SKILL.md)** — 올바른 frontmatter와 구조로 새 doc scaffold.
- **[/python-failure-modes](./.claude/skills/python-failure-modes/SKILL.md)** — Python LLM 안티패턴 cross-reference (리뷰 시).
- **[/review-changes](./.claude/skills/review-changes/SKILL.md)** — PR · 로컬 diff multi-agent 리뷰.
- **[/review-doc](./.claude/skills/review-doc/SKILL.md)** — 단일 doc semantic 리뷰.
- **[/rust-failure-modes](./.claude/skills/rust-failure-modes/SKILL.md)** — Rust LLM 안티패턴 cross-reference (리뷰 시).
- **[/verification-before-completion](./.claude/skills/verification-before-completion/SKILL.md)** — "done" 선언 전 체크리스트.
- **[/zoom-out](./.claude/skills/zoom-out/SKILL.md)** — deep dive 전에 주변 코드 · 시스템 컨텍스트로 한 단계 물러나기.

</details>

### Hooks

[`settings.json`](./.claude/settings.json)에서 wiring한다. matcher → hook 매핑은 [`CLAUDE.md`](./CLAUDE.md#hooks----claudehooks)에 정리되어 있다.

### Rules

LLM이 반복적으로 틀리는 패턴 카탈로그. 관련 skill이 작동할 때 context로 자동 로드된다.

- **[rust-llm-failures.md](./.claude/rules/rust-llm-failures.md)** — Rust 안티패턴.
- **[python-llm-failures.md](./.claude/rules/python-llm-failures.md)** — Python 안티패턴.

### Methodology (`docs/harness/`)

위 컴포넌트들이 따르는 설계 근거 docs. harness를 확장하거나 "왜 이렇게 설계됐는지"가 궁금할 때 참고.

- **[principles.md](./docs/harness/principles.md)** — P1–P12 locked commitment + retired commitment. Surface / LLM Boundary / Severity-as-code / Cost Discipline / Outalator-shape / SapFix-shape / Index Discipline / external-pattern verdict / failure-mode discipline / token-cost exposure / audit-distillation / cost-class rule.
- **[architecture.md](./docs/harness/architecture.md)** — 다섯 Claude Code primitive (hook / cron / subagent / skill / slash command), closed loop, layered enforcement.
- **[doc-pattern.md](./docs/harness/doc-pattern.md)** — doc 타입 매트릭스 (PRD / RFC / ADR / SPEC / TDD / AUDIT / POSTMORTEM / README) + trigger 규칙 + frontmatter schema.
- **[behavior-verification.md](./docs/harness/behavior-verification.md)** — Phase A (structural, CI gate) + Phase B (operator runbook). harness가 주장대로 동작하는지 검증.
- **[components/](./docs/harness/components/)** — PRD + SPEC 쌍:
  - Contract: [hooks SPEC](./docs/harness/components/hooks/SPEC.md), [ci SPEC](./docs/harness/components/ci/SPEC.md)
  - Cron: [c1 docs-audit](./docs/harness/components/cron-c1-docs-audit/)
  - Meta-audit: [skill-audit-harness-coverage](./docs/harness/components/skill-audit-harness-coverage/)

  도메인 특화 state store (error registry · incident store · fix-template library)와 cron (log-scan · bench-validator)은 이 cut에서 패턴 reference로만 남긴다 — [`principles.md`](./docs/harness/principles.md) §3 / §5 / §6의 지침을 따라 본인 프로젝트에서 schema를 정의하고 구현하면 된다.

## Inspiration & Attribution

네 개의 오픈소스 위에 서 있다. attribution은 이 README가 single source — 개별 파일에는 두지 않았다.

### 직접 차용 (Directly adapted)

- **[forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)** (MIT) — `CLAUDE.md` §1, §2, §4, §5는 Forrest Chang의 CLAUDE.md (Andrej Karpathy의 LLM 코딩 함정 관찰을 정리한 것)에서 가져왔다. 로컬 추가: §3 (Read Before You Edit), §6 (Verify Before Claiming Done), §7 (Recover Don't Escalate), 그리고 harness-routing 섹션 전체.

- **[mattpocock/skills](https://github.com/mattpocock/skills)** — Matt Pocock 카탈로그에서 4개 skill 차용:
  - `/grill-with-docs` (+ `CONTEXT.md` / ADR 포맷 컨벤션 — Language / Relationships / Flagged ambiguities + `_Avoid_:` synonym 리스트). 로컬 추가: shared-kernel doc을 root에 두는 multi-context 레이아웃, dense ADR 번호 컨벤션.
  - `/grill-me` — 본문 그대로 차용.
  - `/zoom-out` — `disable-model-invocation` 플래그만 제거 (read-only, $0, deterministic).
  - `/caveman` — 본문 그대로; description의 trigger phrase만 좁혔다 ("be brief" 같은 평범한 표현은 auto-fire 신뢰성이 낮아 제거).

- **[Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)** (OMC, MIT) — `.claude/agents/`의 subagent 파일 포맷이 OMC의 agent shape에서 왔다: `<Agent_Prompt>` XML wrapper + `<Role>` / `<Why_This_Matters>` / `<Success_Criteria>` / `<Constraints>` / `<Investigation_Protocol>` 섹션 (+ 로컬 추가 `<Tool_Usage>` / `<Output_Format>`). 일부 agent 이름 (`code-reviewer`, `critic`, `document-specialist`, `explore`, `security-reviewer`, `test-engineer`, `tracer`)과 writer/reviewer 분리 룰도 OMC에서 직접 가져왔다. 로컬 추가: per-component invariant focus (OMC는 더 generalist 지향), Rust/Python failure-mode rule, auto-fix agent scaffolding (`localizer`, `validator`, `pr-author`).

### 개념적 영감 (Conceptual inspiration)

- **[obra/superpowers](https://github.com/obra/superpowers)** — `/verification-before-completion` skill의 *이름과 핵심 발상*은 Jesse Vincent의 Superpowers framework에서 왔다. 구현은 독립적으로 짰다 (Superpowers의 "Iron Law / Gate Function" 스타일 대신 간결한 체크리스트로). 완료 주장 전에 명시적 verification gate를 둔다는 컨셉 + skill을 framework로 큐레이션한다는 발상이 Superpowers의 영향이다.

### 스타일 영향 (Stylistic influence)

이 README의 전체 구조 — 문제 우선 동기 부여, 그다음 flat reference 리스트 — 는 [mattpocock/skills](https://github.com/mattpocock/skills) README에서 가져왔다. 내용은 직접 작성.

## License

MIT — [`LICENSE`](LICENSE).
