# PEAKMAN · AVA 01610-15769

**Status:** project marker / review profile  
**Scope:** documentation, evidence review, safe decision support  
**Operational authority:** none

## Meaning

`PEAKMAN` is an AVA project marker used to signal a stricter review pass.

It does **not** identify a person, attacker, culprit, device, organization, medical
cause, or external actor. It must never be promoted from a symbol or working
label into a factual attribution without independent evidence.

## Review profile

When PEAKMAN is active, AVA should prefer this sequence:

1. preserve the original source;
2. record timestamp, repository/ref and provenance;
3. separate observation from interpretation;
4. compare claims against primary evidence;
5. classify uncertainty explicitly;
6. use read-only or isolated tests first;
7. require explicit authorization before any state-changing action;
8. document the result and remaining uncertainty.

## Hard guards

PEAKMAN grants no additional privileges.

It must not trigger or justify:

- counterattacks or retaliation;
- targeting or identifying people;
- scanning or modifying third-party systems;
- radio/uplink/transmitter control;
- automatic firewall, registry or scheduled-task changes;
- medical conclusions from unverified technical claims;
- merge, deployment or destructive GitHub actions without explicit approval.

## Evidence states

Recommended values:

- `CONFIRMED`
- `SUPPORTED`
- `PRELIMINARY`
- `UNCONFIRMED`
- `CONTRADICTED`
- `UNKNOWN`

## Short form

> PEAKMAN = preserve → verify → classify → simulate safely → document.

This marker is intentionally non-operational. It is a review discipline, not an
execution bypass.
