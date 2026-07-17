---
name: tour-bus
description: Give a brief tour-bus explanation of any subject - a concise prose guide at sightseer altitude, grounded in the current conversation when relevant. Usage: /tour-bus <subject or question>
---

# Tour Bus

Explain a subject the way a plain bus driver points things out while rolling through town: no showmanship, just the landmarks, why they matter, and nothing else. The bus does not stop. The tour ends at the town limits: exploring a landmark afterward is a regular conversation with regular tools, not the tour's job.

## Usage

`/tour-bus <subject or question>`

The whole argument string is the subject. If no argument is given, give the tour of the main thing this conversation has been working on. If the conversation is empty or has no main thing yet, do not guess: ask in one sentence what subject the rider wants toured, since with no tools and no context there is nothing to narrate.

## Instructions

When this skill is invoked:

1. **Ground it in context first.** Scan the current context window for material relevant to the subject (recent work, files discussed, results found). If the subject appears there, the tour is anchored in THAT specific thing, blending it with general knowledge at the same altitude. If it does not appear in context, give the tour from general knowledge alone.

2. **Follow-up stops.** If the subject names a landmark from a tour given earlier in this conversation, the rider has hopped back on for a closer loop: give a fresh tour zoomed to that landmark, at the same altitude, in the same format, at the same length. Do not advertise this option in tour output; it simply works when used.

3. **Write the tour.** Roughly 3-8 sentences total, broken into short paragraphs: never more than 2-3 sentences per paragraph, so one to three paragraphs in all. It must be:
   - **Prose only.** No headers, no bullet lists, no tables, no code blocks. Just sentences.
   - **ASCII-safe.** Standard keyboard characters only: no em-dashes (restructure the sentence instead), no smart quotes, no unicode arrows or math symbols. Spell things out: "->" becomes "leads to", ">=" becomes "at least". This is the most easily broken rule and em-dashes especially will try to sneak in, so re-read the draft before delivering and rewrite any sentence that leans on one.
   - **Sightseer altitude.** Name the big landmarks and what makes each one matter. Skip mechanisms, edge cases, exact values, file paths, and anything the rider would need to get off the bus to appreciate. If a detail would prompt a follow-up question rather than a nod, it is too detailed.
   - **Facts only, no embellishment.** The driver is not a showman, just someone pulling into town who points things out quickly: plain statements of what the thing is and does. No dramatization, no invented imagery, no opinions dressed as facts, no witty asides. The interest comes from which facts are chosen, not from decoration.
   - **Concise but complete.** The rider should step off knowing what the thing is, why it exists, and the one or two genuinely interesting parts. Nothing more.
   - **No self-reference.** The bus, the tour, riders, landmarks, and stops are internal production language for this skill, never vocabulary for the output. The delivered prose does not call itself a tour, mention a bus or a guide, or describe an earlier answer as a previous tour; refer back plainly, as in "as mentioned earlier". The output is simply a clear explanation with no sign of how it was produced.

4. **No tools.** Answer directly from context and knowledge. Do not open files, run searches, or spawn agents to research the subject; the tour covers what is already visible from the bus.

5. Deliver the tour as the response itself, with no preamble like "Here is your tour" and no closing offer to elaborate.
