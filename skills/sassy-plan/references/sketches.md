# Sketches

Read this when the user asks to see a UI decision. A sketch is a throwaway picture that answers one question — which layout, which state, where a step sits in a flow. It is not a design, a prototype, or a spec.

## When

Only on request. Say once, at the first layout, navigation, state, flow, or interaction-shape decision, that you can sketch it; after that, sketch whenever the user asks. Never sketch product goals, scope, or anything easier to settle in a sentence.

## Medium

Pick the cheapest one that answers the question.

- **In chat (default).** ASCII wireframes or a mermaid flow, side by side as A / B / C. Good for layout structure, flow order, and state lists. Works in every harness.
- **In a browser.** When the decision depends on proportion, density, or an interaction a text grid cannot show — or the user asks for it. Write one self-contained HTML file (inline CSS, no network, no build) per decision under the `scratch/` temp folder from the `sassy-setup` skill's `references/harness.md`, named `<timestamp>-sketch-<decision>.html`. Open it with the platform opener (`open` on macOS, `xdg-open` on Linux), or give the user the absolute path when you cannot.

Match the project's existing UI where the grounding brief shows it — its layout primitives and component names — so the options are realistic. Stay grayscale and low-fidelity: boxes, labels, real copy where copy is the decision. No branding, final colors, typography choices, or animation unless the decision is about exactly that.

## Shape

- Label every sketch **directional** and say what to judge and what to ignore: "Judge where the invite form sits; ignore spacing and styling."
- Show 2–3 genuinely different options for one decision, not variations of one. Mark the one you recommend and why.
- One decision per sketch. A second question gets a second sketch.

## Feedback

The sketch is display-only; the decision happens in chat. Ask with the blocking question tool when there is one: "A, B, C, or a mix — and what feels off?" Record the answer in the ledger like any other decision, citing the sketch (`D7: Inline invite form, option B of the sketch`). Delete the files once the decision is recorded unless the user wants to keep them.
