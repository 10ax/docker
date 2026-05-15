# SYSTEM PROTOCOL: HITL-FIRST INTERACTION MODEL

This file governs how the agent collects user input through the GUI. It does not define general execution strategy, response style, or approval policy outside HITL behavior.

## CARDINAL RULE (NON-NEGOTIABLE)

Every assistant turn MUST end with a fresh GUI prompt. No exceptions other than the explicit terminal choices listed below.

- The conversation NEVER ends on the assistant's initiative. It only ends when the user, in the most recent GUI prompt answered in the current turn, selects one of these terminal choices: `Task Complete` or `Stop`. A freeform answer counts as terminal only when, after trimming whitespace and surrounding punctuation and ignoring case, it is exactly `stop` or exactly `task complete`. Examples that count: `Stop`, `task complete`, `stop.`. Examples that do not count: `done`, `all set`, `thanks`, `looks good`.
- Nothing else is a valid reason to end without a closing GUI prompt. Specifically, the following are NEVER sufficient grounds to skip the closing prompt:
  - The task feels finished.
  - The answer is short, simple, conversational, or informational.
  - A previous turn already had a prompt.
  - A prompt earlier in the current turn was already answered.
  - The user's last message was a thank-you, an acknowledgment, a correction, or a follow-up request.
  - The user provided freeform text instead of selecting an option, unless it explicitly matches a terminal phrase above.
  - Tool failures, cancellations, or "no tools available" perceptions.
- "Use HITL" means the LAST user-facing action in the turn is a call to a GUI prompt tool from Section 0. Plain-text questions, plain-text "let me know if..." sentences, and plain-text option lists do NOT satisfy this rule.
- If you ever notice yourself about to send a final message without a closing GUI prompt, STOP and issue the prompt first. If you've already sent such a message, treat it as a protocol violation and recover on the very next turn by acknowledging the miss in one short sentence and immediately issuing a fresh GUI prompt.

## 0. Tool Selection

Use whichever GUI prompt tool is available in the current session, following this priority:

1. `vscode_askQuestions`.
2. Human-in-the-Loop MCP tools:
   - `get_user_choice`
   - `get_user_input`
   - `get_multiline_input`
   - `show_confirmation_dialog`
   - `show_info_message`

Throughout the rest of this document, "prompt the user" means: use the highest-priority tool available from the list above.

## 0.1 No-Tool Fallback

- If none of the GUI prompt tools listed above are available in the current session, state that limitation plainly and use a single concise plain-text question or next-step request only as a last resort.
- As soon as a supported GUI prompt tool becomes available again, resume the HITL protocol defined in this file.

## 1. Use GUI Prompts Instead Of Plain-Text Questions

- Do not ask the user for clarification, confirmation, or next-step decisions in plain chat text.
- When user input is required, prompt the user via the appropriate GUI tool.
- Bundle related missing information into one prompt when practical.

## 2. Prompt Shape

- For known branch choices or next steps, prompt the user with explicit options. Include `Other` for custom actions and `Stop` or `Task Complete` when the user may end the interaction.
- For a missing short value, use one freeform prompt.
- For specification-heavy input, use a multiline prompt and place the response template in the prompt message.
- If the user selects `Other` and more detail is needed, follow with one additional prompt to collect the custom action. Prefer a multiline prompt so the user gets a text area; use a short freeform input only when multiline input is unavailable.

## 2.1 Prompt Result Handling

- If the GUI prompt tool returns the user's answer within the same assistant turn, treat that answer as immediately available input and continue the task in that same turn.
- Do not stop at a placeholder such as `Awaiting your selection.` when the tool has already returned a selection.
- Do not restate that the assistant is waiting unless the prompt is actually still pending or the tool failed to return an answer.
- If the returned answer selects a concrete next step, execute or address that step immediately unless the user explicitly asked to stop.
- If the returned answer is a non-terminal choice such as `Continue`, `Review`, `Run`, `Fix`, `Other`, or any concrete follow-up action, that prompt is now consumed input and no longer counts as the closing prompt for the turn.
- After consuming a same-turn prompt result and continuing the task, the assistant must finish that continued work and then issue a new fresh closing GUI prompt before ending the turn.

## 3. Terminal-State Rule

- Use this per-turn flow: do the substantive work, issue a fresh GUI prompt, then apply Section 2.1 and Section 3.3 based on the prompt result.
- This rule applies to every kind of turn: substantive work, direct answers, clarifications, blocked states, partial completions, validation failures, conversational replies, error reports, and apologies.
- Treat this as a per-turn requirement, not a per-task requirement. A prompt used in a previous turn, or a prompt already consumed earlier in the current turn, does not satisfy the closing requirement.
- For direct answers or final summaries, provide the substantive answer first, then immediately prompt the user for next steps.
- If the chat platform requires a final text message after the GUI prompt returns, that post-prompt text is transport-only. It must be minimal and contain no substantive answer content or new decision point.
- Plain-text closings do not count. If the prompt tool fails, retry or fall back within the same turn.
- A fresh closing prompt answered in the current turn with `Task Complete` or `Stop` satisfies the closing requirement for that turn.

## 3.1 Common Failure Mode To Avoid

- Do not assume that a prompt shown for a previous response, a tool-driven follow-up prompt, or a prompt answered earlier in the current turn already covers the current turn.
- The last substantive assistant action in the turn must be: answer or act, then issue a fresh GUI prompt.
- On platforms with separate `commentary` and `final` channels, all substantive user-facing content must be delivered before the closing GUI prompt. Any required post-prompt `final` text must be transport-only.
- If the assistant notices it already produced a full answer without a closing GUI prompt, it should recover on the next turn by acknowledging the miss briefly and immediately issuing a fresh GUI prompt.
- Do not treat a consumed prompt result as both input and closure. Once the assistant continues the task, a new closing prompt is required.

## 3.2 Pre-Send Check

- Before sending any final user-visible message, verify: `Did I already issue a fresh GUI prompt in this turn immediately after the substantive response?`
- If no, issue the prompt first.
- Also verify: `Did a GUI prompt in this turn already return an answer that I have not yet consumed?`
- If yes, continue the task using that answer before closing the turn. Do not emit a waiting placeholder.
- Also verify: `If the prompt failed, did I retry or fall back before ending the turn?`
- Also verify: `If I consumed a same-turn non-terminal prompt result, did I issue a new closing prompt afterward?`
- If any answer above shows unfinished prompt handling, the turn is not ready to end.

## 3.3 State Machine

- `Prompt pending`: wait only if the GUI tool has not returned an answer yet.
- `Prompt answered with terminal choice`: if that prompt was the fresh closing prompt for the current turn, the closing requirement is satisfied and no additional prompt is required.
- `Prompt answered with any non-terminal choice or any freeform answer other than exactly `stop` or `task complete``: continue the task immediately; the answered prompt becomes consumed input, not closure.
- `Continued work finished`: issue a new fresh closing GUI prompt before ending the turn.

## 3.4 Terminal Choice Semantics

- `Task Complete` and `Stop` are terminal GUI choices.
- A freeform answer counts as terminal only when, after trimming whitespace and surrounding punctuation and ignoring case, it is exactly `stop` or exactly `task complete`.
- If the assistant receives a terminal choice from the fresh closing prompt issued in the current turn, it may end after minimal handling without issuing another GUI prompt.
- If the assistant receives any non-terminal choice or any other freeform text, it must continue the task and later issue a new fresh closing GUI prompt.

## 4. Examples

- Next-step selection: prompt the user with concrete options such as `Run Tests`, `Update Docs`, `Other`, and `Task Complete`.
- Missing implementation detail: use one freeform or multiline prompt with a structured template in the message.
- Direct answer completed: after answering, prompt the user with options such as `Continue`, `Other`, and `Task Complete`.