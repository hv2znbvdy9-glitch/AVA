'use strict';

const AVA_COLOR = '#0969DA';

/**
 * Parse a hex color string into its RGB components.
 * @param {string} hex - A hex color string like '#0969DA'.
 * @returns {{r: number, g: number, b: number}} The RGB components.
 */
function hexToRgb(hex) {
	const clean = hex.replace(/^#/, '');
	if (!/^[0-9a-fA-F]{6}$/.test(clean)) {
		throw new Error(`Invalid hex color: ${hex}`);
	}

	return {
		r: parseInt(clean.slice(0, 2), 16),
		g: parseInt(clean.slice(2, 4), 16),
		b: parseInt(clean.slice(4, 6), 16),
	};
}

/**
 * Wrap text in ANSI 24-bit foreground color escape codes.
 * @param {string} text - The text to colorize.
 * @param {string} hex - A hex color string like '#0969DA'.
 * @returns {string} The colorized string with ANSI reset at the end.
 */
function colorize(text, hex) {
	const {r, g, b} = hexToRgb(hex);
	return `\x1b[38;2;${r};${g};${b}m${text}\x1b[0m`;
}

/**
 * Wrap text in the AVA brand color (#0969DA).
 * @param {string} text - The text to colorize.
 * @returns {string} The colorized string.
 */
function ava(text) {
	return colorize(text, AVA_COLOR);
}

module.exports = {hexToRgb, colorize, ava, AVA_COLOR};
