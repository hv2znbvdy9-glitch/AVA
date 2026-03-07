'use strict';

const AVA_COLOR = '#0969DA';

/**
 * Convert a hex color string to an {r, g, b} object.
 * @param {string} hex - Hex color string (e.g. '#0969DA' or '0969DA').
 * @returns {{r: number, g: number, b: number}}
 */
function hexToRgb(hex) {
	const clean = hex.replace(/^#/, '');
	const int = parseInt(clean, 16);
	return {
		r: (int >> 16) & 0xff,
		g: (int >> 8) & 0xff,
		b: int & 0xff,
	};
}

/**
 * Wrap text in ANSI 24-bit foreground color escape codes.
 * @param {string} text - Text to colorize.
 * @param {string} hex - Hex color (e.g. '#0969DA').
 * @returns {string}
 */
function colorize(text, hex) {
	const {r, g, b} = hexToRgb(hex);
	return `\x1b[38;2;${r};${g};${b}m${text}\x1b[0m`;
}

/**
 * Returns the AVA brand label colored with the brand color.
 * @returns {string}
 */
function ava() {
	return colorize('AVA <2', AVA_COLOR);
}

module.exports = {AVA_COLOR, hexToRgb, colorize, ava};
