'use strict';

const NAME_MAX = 40;
// Letters (any script), marks, spaces, apostrophes, hyphens and dots.
const NAME_PATTERN = /^[\p{L}\p{M}][\p{L}\p{M} '.-]*$/u;

/**
 * Validates the body of POST /api/greet.
 * Returns { value } on success or { error } with a human readable reason.
 */
function validateGreetBody(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'Request body must be a JSON object' };
  }
  if (typeof body.name !== 'string') {
    return { error: '"name" is required and must be a string' };
  }
  const name = body.name.trim();
  if (name.length === 0) {
    return { error: '"name" must not be empty' };
  }
  if (name.length > NAME_MAX) {
    return { error: `"name" must be at most ${NAME_MAX} characters` };
  }
  if (!NAME_PATTERN.test(name)) {
    return { error: '"name" may only contain letters, spaces, apostrophes, hyphens and dots' };
  }
  return { value: { name } };
}

module.exports = { validateGreetBody, NAME_MAX };
