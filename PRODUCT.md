# Product

## Register

product

## Users

Two overlapping personas sharing the same app:

1. **Member** — Nigerian individual contributing to one or more savings groups (beels). Core job: deposit on schedule, track their balance and payout timeline, know when they're next to collect.
2. **Admin / Group organiser** — Manages a beel: invites members, sets amounts and recurrence, triggers withdrawals. Core job: keep the group running smoothly and transparent.

Context: mobile-first usage, often on mid-range Android phones, in home or office settings. Users are financially literate but not tech-first. Trust is the primary purchase.

## Product Purpose

Beels digitalises the traditional Nigerian ajo/esusu group savings model. It makes contribution tracking, payout scheduling, and bills payment simple and trustworthy for ordinary Nigerians who already run informal savings circles.

Success looks like: a member can check their position in a beel, see what they've contributed, and know when they'll receive their payout — in under 30 seconds, with full confidence.

## Brand Personality

Modern, sharp, trustworthy. Premium without being cold.

Three words: **Precise. Grounded. Confident.**

The app should feel like the fintech equivalent of a well-run cooperative bank — not a startup toy, not a corporate portal.

## Anti-references

- Generic African fintech visual language: green + orange palettes, cartoon mascots, "youthful" gradients (Kuda, Opay, Palmpay aesthetic)
- Western-SaaS cream: beige backgrounds, Notion-style minimalism, excessive whitespace, serif editorialising
- Bootstrap default: grey admin tables, stock icon sets, out-of-the-box template feel — exactly what the current Tabler skin looks like

## Design Principles

1. **Trust is visual** — every number must be legible, every state must be explicit. Ambiguity (loading, empty, error) is never acceptable.
2. **Data earns its space** — tables and numbers are the product; they get the best treatment, not an afterthought.
3. **No decoration for decoration's sake** — every border, gradient, and shadow must do functional work.
4. **Status is never ambiguous** — contribution status, transaction type, and amounts must be immediately scannable with colour and shape.
5. **Mobile first, desktop dignified** — design for the mid-range Android first, then use the extra desktop space for richer context, not just bigger margins.

## Accessibility & Inclusion

- WCAG AA minimum (contrast ratios, focus states)
- All colour-coded status indicators must have a non-colour signal (label, icon, or shape)
- Reduced-motion: animations are progressive enhancement only

## Mobile Notes

- Flutter, Android-first, mid-range devices: keep animations cheap (transform/opacity), no heavy blur.
- Thumb reach: primary actions live in the lower half; bottom sheets over dialogs.
- Every async surface has explicit loading (skeleton), empty, and error states with a retry.
- Haptics on confirm/success/error only; never on scroll or idle taps.
