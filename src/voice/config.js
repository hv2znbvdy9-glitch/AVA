'use strict';

const profile = require('../../profiles/AVA_RADIO_01610-1.json');

const AVA_RADIO_PROFILE = Object.freeze({
	...profile,
	effects: Object.freeze({...profile.effects}),
});

module.exports = {AVA_RADIO_PROFILE};
