# F4 — Ideal-state fidelity

Plan: `.omo/plans/offline-playtest-qa.md` Final Verification Wave F4.
1:1 against IS-1…IS-5. Shortfall would become new `- [ ] N.` rows.

**VERDICT: APPROVE**

| IS | Delivering todo | Proof | Shortfall? |
| --- | --- | --- | --- |
| IS-1 remaining misses catalogued; autotest does not flood | 1 | catalog exists; autotest once-log per name; extra youli `1004/52/50/54` are the same mismatch class as `{18,30,38,74,siwang}` (file present, names absent). Not a new implementation todo: catalog-only, no `.motion` generated. Recorded in F3 evidence. | no new `- [ ]` — same GAP-1 class |
| IS-2 U on mage is real attack clip 10100, not lilimu `'0'` | 5 | PlayerKit: 104 slot A = 980000, action 10100; autotest no lilimu `'0'` | none |
| IS-3 every profession-tree skill on a key or Debug Cast | 5, 6 | dump lists leaves; overflow Cast via `presetSkill`; fighter `no profession tree` | none |
| IS-4 collision boxes behind switch, default off | 3 | DebugDraw `m_enabled=false`; F8 + ImGui; `present` returns when disabled | none |
| IS-5 mugen-rewrite F3 stays `[~]` | guardrail | `.omo/plans/mugen-rewrite.md` line 1349 `- [~] F3. Real manual QA` | none |

No new implementation checkbox required. Extra youli names stay catalog-class mismatch; this plan forbids inventing clips.
