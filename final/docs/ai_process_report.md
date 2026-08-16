# AI Development Process Report

**Final deliverable 3.** How the platform was actually built with AI assistance,
including what failed. Written from the session transcript, not reconstructed.

---

## 1. How the work was structured

The project was built in a single extended Claude Code session, with the human
acting as analyst and decision-maker and Claude as implementer. Roughly:

| Activity | Human | Claude |
|---|---|---|
| Business questions and KPI selection | decided | proposed options |
| Data forensics | directed | executed and analysed |
| Technology choice | approved | researched, recommended |
| SQL, scripts, infrastructure | reviewed | wrote |
| Verification strategy | demanded | designed and ran |
| Judgment calls on ambiguous data | **decided** | framed the trade-off |

The most valuable division was the last row. Twice, the correct answer was not
derivable from the data, and Claude presented structured options rather than
guessing — the burn definition and the CAC cohort definition. Both changed the
headline numbers materially.

## 2. Phase-by-phase

**Phase 1 — Discovery.** Claude profiled the CSVs and found something the
project documentation did not contain: `raw_operating_costs` mixes a cash
*balance* into the same column as five *cost* categories, so an unfiltered sum
returns 15× the truth. This was found by sanity-checking a magnitude
(€51,000/month against €1,500/month of revenue), not by any test.

**Phase 2 — Architecture.** Postgres and Metabase were selected under time
pressure and, honestly, by fiat rather than through the research process the
spec describes. The ADR says so explicitly. The Lightdash trade-off — dbt-native
semantic layer versus 90 minutes of extra setup — is documented as a real,
still-open cost.

**Phase 3 — Database.** Schema, loaders and a data-quality gate. Five
environment failures, none of them in SQL (see §4).

**Phase 4 — Modelling.** Built twice. First as flat per-metric marts, then
restructured to a Kimball star when the human asked what methodology was in use.
The second structure was better, and the question that prompted it was worth
more than any code Claude wrote that hour.

**Phase 5 — BI.** Two dashboards, 18 cards, provisioned entirely from code.

**Phase 6 — Automation.** `start.sh` from cold in 261 s, verified repeatedly
from `docker compose down -v`.

## 3. Where AI was genuinely strong

**Data forensics.** The standout. The cash ledger contradicted the P&L by
€85,519 and the question was whether that was an accounting phenomenon or an
error. Claude enumerated the legitimate mechanisms (accrual timing, non-cash
expenses, financing, working capital), argued why each was inconsistent with the
observed shape, then fitted the series: monthly cash change is **linear in time
at R² = 0.971**, correlating +0.985 with the clock and only +0.401 with revenue.

That converted "these numbers disagree" into "this series is synthetic, and here
is the evidence" in about two minutes. Doing it by hand would have taken an hour
and probably stopped at the correlation matrix.

**Mechanical breadth.** 25 dbt models, 77 tests, a provisioning script, schema
DDL and a startup script, with consistent commenting throughout.

**Explaining its own artefacts.** Compiling the same models against two adapters
and diffing the output to show what `ref()` and `source()` actually do was a
better explanation than prose.

## 4. Where AI failed, and the pattern

Every significant failure was the same shape: **something reported success while
being wrong.**

| Failure | How it presented | How it was caught |
|---|---|---|
| Colima defaulted to QEMU | **Silent hang**, no output, 6 minutes | Checking whether bytes were landing on disk |
| Resumed a corrupt 277 MB partial | Byte count matched exactly | `gzip -t` after the fact — should have been before |
| `sync_schema` on every poll | Sync restarted forever, wait expired | Manual sync succeeded in 25 s |
| Cards reused by name, not updated | Provisioning reported success; 5 cards broken | Executing every card |
| Orphaned card left behind | Invisible in the success output | Executing every card |
| CAC returned `0.00` for 2022–23 | A plausible-looking number | Reading output and asking if it was believable |
| LTV implied a 19-year lifetime | All 102 tests passed | Reading output and asking if it was believable |

The last three matter most. **All tests passed while the numbers were wrong.**
Tests check the properties you thought to assert; they cannot tell you an LTV of
€3,515 implies a customer relationship lasting until 2045.

The corrupt-download episode is the clearest self-inflicted wound: 277 MB of
progress was resumed onto without integrity-checking the prefix first, producing
a byte-perfect corrupt file and forcing a restart from zero over a 100 KB/s
connection.

## 5. Skills

`Requirements.md` asks which Claude Code skills were invoked and which paid off.

**None were available.** `ListPlugins` returned empty and the org catalogue had
no matches, so `/brainstorming`, `/writing-plans`, `/executing-plans`,
`/test-driven-development`, `/systematic-debugging`,
`/verification-before-completion` and `/requesting-code-review` — all referenced
throughout `CLAUDE.md` — did not exist in the session. Installing the
`superpowers` marketplace requires an interactive terminal panel that the
initial environment could not open.

This is worth recording plainly: **the playbook assumed tooling that was not
present, and would have silently done nothing had it been invoked.** The
practices those skills encode (plan before acting, verify before claiming, test
first) were applied manually instead, unevenly — test-first in particular was
not followed; models were written before their tests.

## 6. AI-assisted versus traditional

**Faster:** boilerplate, SQL across many models, API integration against
under-documented endpoints, and statistical analysis on demand. The star schema
restructure — 13 new models — took minutes.

**Not faster:** anything gated on the physical world. Roughly half the elapsed
session went to a 316 MB download on a throttled connection. No amount of model
capability compresses that.

**Actively dangerous without review:** confident wrong output. The LTV of €3,515
was produced with correct formulas, passing tests, and a plausible-looking
number. A reviewer who trusted the green build would have shipped it.

**The highest-leverage human contributions** were both questions, not
corrections:
- *"What methodology are you using — use Kimball if possible"* → replaced a
  rigid reporting structure with a dimensional one, and made nine drill-downs
  free.
- *"What is the reason that the ledger contradicts the P&L?"* → turned a
  documented caveat into a proven finding with a regression behind it.

## 7. Recommendations

1. **Execute the artefact, never trust the success message.** Provisioning said
   success while five cards were broken. Run the cards, run the query, load the
   page.
2. **Sanity-check magnitudes against a known anchor.** €51,000/month of costs
   against €1,500/month of revenue; a 19-year customer lifetime. Both wrong,
   both plausible-looking, neither caught by tests.
3. **Verify integrity before building on a partial.** Check the prefix before
   resuming a download; check the schema before reusing a card.
4. **Make the model state assumptions explicitly and surface the alternative.**
   Reporting both attributed CAC (€238.24) and blended CAC (€1,013.72) exposed
   that LTV:CAC is 3.84 or 0.90 depending on the question — far more useful than
   one confident number.
5. **Ask what methodology is in use, early.** The single highest-value question
   of the project, and it arrived late enough to require rework.
6. **Confirm tooling exists before relying on a playbook that references it.**
   A skill that silently does nothing is worse than one that errors.
