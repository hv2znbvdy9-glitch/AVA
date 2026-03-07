'use strict';

const OVERVIEW_TEXT = `AVA <2 — Session Overview

Starting a new session, whether for coaching, technical work, or creative
endeavors, requires intentional preparation to ensure effectiveness, focus,
and productivity.

Structure & Preparation:
  • Talk   (5–10 min)  — Set goals and context for the session
  • Train  (25–30 min) — Active working session
  • Test   (5 min)     — Review and conclude

Contextual Setup:
  In technical environments, begin by setting up the environment,
  e.g. creating a named tmux session: tmux new -s sessionName

Review and Continuity:
  Ensure continuity by reviewing past notes or feature lists before
  starting a new session to prevent bugs and maintain workflow.

Information Gathering:
  A pre-session questionnaire can enhance effectiveness, allowing for
  customized approaches and clearer goal-setting.

Engagement Strategies:
  Kick off sessions with interactive methods — play a game, share a
  story, or use "3 Interesting Ways to Begin"!

By establishing a clear, organized start, you set the stage for a
productive session.`;

/**
 * Returns the AVA session overview text.
 * @returns {string}
 */
function overview() {
	return OVERVIEW_TEXT;
}

module.exports = {overview, OVERVIEW_TEXT};
