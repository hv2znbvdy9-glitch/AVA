'use strict';

const START_BANNER = `START - JETZT!

AVA <2 — Session Start

Structure & Preparation:
  • Talk   (5–10 min) — Set goals and context
  • Train  (25–30 min) — Active working session
  • Test   (5 min)    — Review and conclusion

Contextual Setup:
  • Ensure your environment is ready (e.g. tmux new -s sessionName)

Review and Continuity:
  • Check past notes or feature lists before starting

Let's go!`;

/**
 * Print the AVA session start banner to stdout.
 */
function start() {
	console.log(START_BANNER);
}

module.exports = {start, START_BANNER};
