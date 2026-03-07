'use strict';

const {run} = require('./run');

module.exports = {run};

// When run directly (not imported as a module), execute a demo command
if (require.main === module) {
	console.log('AVA task runner demo');
	console.log('===================\n');
	const result = run('echo "Hello from AVA!"', {silent: false});
	console.log(`\nCommand completed with exit code: ${result.exitCode}`);
}
