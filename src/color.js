'use strict';

const AVA_COLOR = '#0969DA';

/**
 * Convert a hex color string to RGB components.
 * @param {string} hex - Hex color string (e.g. "#0969DA" or "0969DA").
 * @returns {{r: number, g: number, b: number}} RGB components.
 */
function hexToRgb(hex) {
	const clean = hex.replace(/^#/, '');
	const value = parseInt(clean, 16);
	return {
		r: (value >> 16) & 0xff,
		g: (value >> 8) & 0xff,
		b: value & 0xff,
	};
}

/**
 * Wrap text with ANSI 24-bit foreground color escape codes.
 * @param {string} text - The text to colorize.
 * @param {string} hex - Hex color string.
 * @returns {string} ANSI-colored string.
 */
function colorize(text, hex) {
	const {r, g, b} = hexToRgb(hex);
	return `\x1b[38;2;${r};${g};${b}m${text}\x1b[0m`;
}

/**
 * Return the AVA brand text colorized with the brand color.
 * @returns {string} Colorized AVA brand text.
 */
function ava() {
	return colorize('AVA <2', AVA_COLOR);
}

module.exports = {hexToRgb, colorize, ava, AVA_COLOR};
