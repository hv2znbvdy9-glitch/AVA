'use strict';

const sessionOverview = [
	'AVA <2 Session Overview',
	'',
	'Starting a new session, whether for coaching, technical work, or creative endeavors, requires intentional preparation to ensure effectiveness, focus, and productivity.',
	'',
	'Key approaches for initiating a new session include:',
	'',
	'- Structure & Preparation: For coaching or training, implement a "talk, train, test" format. Start with a 5-10 minute conversation on goals, followed by a 25-30 minute active training session, and conclude with a review.',
	'- Contextual Setup: In technical environments (like terminal or coding sessions), begin by setting up the environment, such as creating a named tmux session (tmux new -s sessionName).',
	'- Review and Continuity: Ensure continuity by reviewing past notes or feature lists before starting the new session to prevent bugs and maintain workflow.',
	'- Information Gathering: Utilizing a pre-session questionnaire can significantly enhance the effectiveness of the first meeting, allowing for customized approaches and clearer goal setting.',
	'- Engagement Strategies: Kick off sessions with interactive methods like playing a game, sharing a story, or using "3 Interesting Ways to Begin"!.',
	'',
	'By establishing a clear, organized start, you set the stage for a productive session.',
].join('\n');

function getSessionOverview() {
	return sessionOverview;
}

module.exports = {getSessionOverview};
