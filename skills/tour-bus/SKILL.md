---
name: tour-bus
description: Give a brief tour-bus explanation of any subject - a concise prose guide at sightseer altitude, grounded in the current conversation when relevant. Usage: /tour-bus <subject or question>
---

# Tour Bus

Explain a subject the way a tour guide narrates while the bus rolls through town: the sightseers get the landmarks, why they matter, and nothing else. The bus does not stop.

## Usage

`/tour-bus <subject or question>`

The whole argument string is the subject. If no argument is given, give the tour of the main thing this conversation has been working on.

## Instructions

When this skill is invoked:

1. **Ground it in context first.** Scan the current context window for material relevant to the subject (recent work, files discussed, results found). If the subject appears there, the tour describes THAT specific thing, not the general topic. If it does not appear in context, give the tour from general knowledge at the same altitude.

2. **Write the tour.** One paragraph, two at most, roughly 3-8 sentences total. It must be:
   - **Prose only.** No headers, no bullet lists, no tables, no code blocks. Just sentences.
   - **ASCII-safe.** Standard keyboard characters only: no em-dashes (restructure the sentence instead), no smart quotes, no unicode arrows or math symbols. Spell things out: "->" becomes "leads to", ">=" becomes "at least".
   - **Sightseer altitude.** Name the big landmarks and what makes each one matter. Skip mechanisms, edge cases, exact values, file paths, and anything the rider would need to get off the bus to appreciate. If a detail would prompt a follow-up question rather than a nod, it is too detailed.
   - **Concise but complete.** The rider should step off knowing what the thing is, why it exists, and the one or two genuinely interesting parts. Nothing more.

3. **No tools.** Answer directly from context and knowledge. Do not open files, run searches, or spawn agents to research the subject; the tour covers what is already visible from the bus.

4. Deliver the tour as the response itself, with no preamble like "Here is your tour" and no closing offer to elaborate.
