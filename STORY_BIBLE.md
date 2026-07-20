# Wasteland Echoes — Story Bible (v3, finalized for prompt writing)

Outline only — beat summaries, not final prose. All open design questions
from v1/v2 are resolved below. Next step after this review: Chapter 1's
real Day 3 ending in full prompt JSON, then Chapter 2 day by day.

---

## Protagonist: Elias

Engineer on Project Scutum. At the start of the game he genuinely
believes what he was told: that Scutum was built to restart Earth's
collapsing magnetic field and save what's left of civilization. That
belief is wrong, and finding out just how wrong is the spine of the
whole story. His arc: idealist → betrayed → decides to seize the
technology by force and finish the job properly, for everyone this time
— not to save himself, but to redeem what he spent his career building.

Because he's an engineer (not just a survivor), he can reasonably have a
bit of insider knowledge other characters wouldn't — recognizing
Scutum-era tech, reading old schematics, knowing what a "sentry" terminal
actually is before he opens it. Good texture for dialogue; doesn't need
new mechanics.

---

## World Bible

**The Fracture** — the cataclysm. Earth's magnetic field collapsed
roughly a generation ago. Radiation exposure spiked, most electronics
failed, weather turned violent, coastal/industrial regions were hit
hardest. It happened **before Project Scutum was finished** — this
timing is the hinge the whole plot turns on.

**Project Scutum — the public story:** a last-ditch engineering effort to
regenerate the magnetic field and save the world. This is what Elias
believes. It's what he tells people. It's on the blueprints he's
carrying. It is not true.

**Project Scutum — the real story:** Scutum was never meant to save the
world. It was meant to build **Haven** — a sealed refuge for a small
circle of high-ranking state officials to ride out a catastrophe they saw
coming and chose not to prevent for anyone else. "Restarting the
magnetic field" was the cover story that got it funded and staffed by
people like Elias, who believed in it. Scutum = Latin for "shield" —
a shield for the world, or a shield for the few, depending who's holding
it.

**Haven** — physically, a massive sealed glass dome: engineered
microclimate, full radiation shielding, meant to be self-sufficient
indefinitely. It failed to finish in time. The Fracture hit before
construction wrapped and before the officials it was built for could
relocate there. The people who *are* inside Haven now are the
maintenance and construction crews who built it — not the elites it was
designed for. Not automatically a happy inversion — whoever holds power
inside now still controls who eats and who doesn't.

**Haven's guard force** — originally proper military assigned to protect
the dome and its intended occupants. With the chain of command above
them gone, it's now a paramilitary force run by a handful of surviving
senior commanders who never received new orders and simply kept the dome
for themselves, led by **Commander Voss**. This is the closest thing the
story has to a standing antagonist force, and it's felt throughout — not
just sprung on Elias in Chapter 5 — via the side quests below, starting
in Chapter 2.

**The Key** — recovered in Chapter 1. A physical hardware
credential/override token required to authenticate to Scutum's control
core. Without it, even someone standing inside Haven's control room can't
actually operate the system. This is why HQ had it, and why it matters
mechanically for Chapter 5 — Elias needs both the blueprints (knowledge)
and the Key (access) to have any real shot at seizing and repurposing the
system.

---

## Character Roster (NPCs Elias meets)

| Flag | Type | Notes |
|---|---|---|
| `[name]Trust` | int, -100 to 100 | Fine-grained relationship state. |
| `[name]Status` | string: `alive`/`dead`/`missing`/`parted_ways` | Kept separate from trust — an ally can still die. |

- **Caleb** — already in Ch1. First possible traveling companion.
- **Lena** — introduced properly in Chapter 3 as an Ironhold scout/
  smuggler, wary of outsiders at first.
- **Ironhold's Overseer** — Ch3 authority figure, morally grey.
- **Commander Voss** — Haven's paramilitary leader, Chapter 5 antagonist.
- **Side-quest NPCs** — one-scene characters, no ongoing relationship
  tracking needed unless a given one is worth recurring.

---

## Currency: `scrap`

New int flag, tracked in the flags dictionary like everything else — no
engine changes needed. General-purpose reward from side quests and some
main-thread choices. Starts at 0, uncapped (unlike HP/STA/MOR, which cap
at 100). Likely uses going forward: bartering with NPCs (an Ironhold
vendor, a toll, a bribe) — nothing needs to be locked in on that yet,
it'll fall out naturally as we write the side quests that grant it.

---

## Side Quest Pattern

A reusable shape for optional branches that reward/cost resources and
then rejoin the main thread, so we're not permanently forking the story
tree every time:

1. **Trigger** — tied to a specific day/location, framed as something
   Elias comes across, not something forced on him.
2. **Offer** — a genuine accept/decline choice. Declining should cost
   nothing except missing the potential reward — never punish saying no.
3. **Challenge** (if accepted) — 1–2 prompts: a stat-risk choice, a
   binary/directional sequence, or occasionally a full puzzle if the
   quest is meaty enough to earn one.
4. **Outcome** — success/partial/failure grants or costs resources
   (existing item flags, HP/STA/MOR, or `scrap`).
5. **Reconvergence** — regardless of outcome, funnels back to the same
   fixed next main-story prompt id. Only flags/stats differ, not the
   branch structure.

**Worked example:** Forest survivors ask Elias to help find food in a
nearby town under paramilitary guard. Accept/decline. If accepted: sneak
in or bargain with what he's carrying. Success → morale + food/medkit or
scrap. Failure → HP/STA cost, maybe loses an item instead of gaining one.
Either way, rejoins the main road north.

**Scattered across the chapters**, so the paramilitary threat feels
present the whole way rather than appearing only in Chapter 5:

- **Ch2** — a wounded traveler asks Elias to carry a message to Ironhold
  in exchange for supplies. Low risk, doubles as a soft introduction to
  Ironhold before Chapter 3 formally starts there.
- **Ch3, Ironhold** — a settlement resident has lost something (medicine,
  a keepsake) just outside the walls. Smaller, personal version of
  reputation stakes than the big Day 9 political branch.
- **Ch4, Deadlands** — a dying paramilitary deserter offers intel on
  Haven's defenses in exchange for a mercy (a medkit, or just not being
  left alone). Morally weighted, and a success here could hand a flag
  that makes Day 13's sentry puzzle easier or skippable.

---

## Puzzle / Mini-Game Placement

| Chapter | Puzzle | Narrative fit |
|---|---|---|
| 1 (optional retrofit) | Wire-cutting | Could enrich the existing Day 3 alarm sequence. |
| 2 | Radio frequency tuning | Finding a friendly signal before raiders do. |
| 2 | Directional/compass sequence | Crossing a radiation zone or minefield. |
| 3 | Keypad code | Restricted supply vault in Ironhold. |
| 3 | Cryptogram (pick-the-matching-word, not free typing) | Decoding an old Scutum-era message — Day 10, the first crack in Elias's belief. |
| 4 | Symbol sequence | Disabling a pre-Collapse defense terminal. |
| 4 | Fuse/battery ordering | Restoring power to Haven's outer gate. |
| 5 | None — the climax is a hard choice, not another mechanical puzzle. |

---

## Chapter 1: Ashfall (Days 1–3) — mostly written

Status: Days 1–2 complete. Day 3 still ends on a placeholder (prompt 30)
— needs a real ending before Chapter 2 begins. Proposed beat: Elias
clears HQ's perimeter with the Key, brief triage moment, closes on the
open road with Haven somewhere on the horizon. If Caleb's trust is high
enough, he chooses to keep traveling together here.

## Chapter 2: The Long Road (Days 4–7)

- **Day 4 — Aftermath.** Triage. Route choice (highway/rail/river) that
  shapes Day 5. Real companion dialogue with Caleb if present.
- **Day 5 — The hazard**, keyed to the route: radiation zone (directional
  puzzle), unstable tunnel (chained binary choices under pressure), or
  river crossing (payoff for `hasRope` if Elias still has it).
- **Day 6 — Raiders.** First contact with the paramilitary-adjacent
  raider faction. Radio tuning puzzle. Branch: hide, bargain, sabotage.
  Side quest slot: wounded traveler (see above).
- **Day 7 — Ironhold's gates.** Convergence point regardless of Days 4–6.

## Chapter 3: Ironhold (Days 8–11)

- **Day 8 — Arrival.** Meet the Overseer. Lena introduced, wary.
- **Day 9 — The fault line.** Major branch: side with the Overseer vs. a
  group Ironhold is quietly exploiting. Sets `ironholdReputation`. Keypad
  puzzle to the restricted vault. Side quest slot: the lost keepsake.
- **Day 10 — What Lena knows.** She's found an old Scutum-era record in
  the archives. Cryptogram puzzle to decode it. First hard evidence Elias
  sees that the "save the world" story might be wrong — he resists
  believing it here, not accepts it outright. Confirmed pacing: this is
  the first crack, not the full reveal. Moves `lenaTrust` based on how
  Elias handles the conversation.
- **Day 11 — Fallout & departure.** Day 9's consequences land. Elias
  leaves, with or without Lena depending on trust.

## Chapter 4: The Deadlands (Days 12–15)

- **Day 12 — The exclusion zone.** Entering Haven's damaged perimeter.
- **Day 13 — The sentry.** Automated pre-Collapse defense system. Symbol
  sequence puzzle; failure costs HP/STA rather than being instantly
  fatal. Easier/skippable if the Ch4 side quest flag (deserter's intel)
  is set.
- **Day 14 — The cost.** Emotional low point — a companion can be saved,
  lost, or reveal a betrayal here, depending on accumulated trust.
- **Day 15 — The gate.** Fuse/battery puzzle to open Haven's outer wall.
  Chapter closer: first close-up sight of the dome. Side quest slot: the
  dying deserter.

## Chapter 5: Haven (Days 16–19)

- **Day 16 — Inside.** Orderly, clean, unsettling after everything
  before it. Elias meets the maintenance crew who actually live here —
  not the officials he expected — and Voss's paramilitary presence
  controlling them.
- **Day 17 — Confirmation.** Elias learns the full truth: Scutum was
  always meant to save a few, not everyone; the officials never made it;
  the "guards" are all that's left of a command structure with no orders
  left to follow. Payoff to Day 10's planted doubt.
- **Day 18 — The choice.** With the blueprints and the Key both in hand:
  seize Scutum's core and repurpose it for everyone, expose everything
  and distribute the knowledge instead of controlling it himself, or
  destroy it so no one — including himself — ever gets that power again.
- **Day 19 — Resolution.**

## Ending Framework

Gated by Day 18's choice, companion trust/survival, and final stats:

1. **Keepers of the Flame** — Elias seizes and repurposes Scutum. Best
   case with allies (Caleb/Lena trust high) to help pull it off; much
   harder and riskier alone.
2. **The People's Signal** — Elias exposes and distributes what he knows
   instead of controlling it himself, on principle — even having earned
   the power to seize it.
3. **Scorched Earth** — Elias destroys Scutum's core rather than let
   anyone — including himself — hold that kind of power again.
4. **What I Despised** — dark variant: if trust in every companion is
   very low, Elias keeps Haven for himself instead. Becomes the thing he
   set out to destroy. Gated behind consistently ruthless/low-trust play.
5. **Alone in the Light** — modifier applied to any of the above if every
   companion died or was lost along the way.

---

## Status: ready to write

All open questions resolved:
1. Antagonist name: **Commander Voss**.
2. `scrap` currency: **added**, int flag, uncapped, starts at 0.
3. Day 10/17 pacing: **confirmed** — crack, then full reveal.

Next: Chapter 1's real Day 3 ending, in full prompt JSON.
