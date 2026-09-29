# Card game (deck battler, duel, solitaire-like)

A card game is mostly UI, so it succeeds or fails on **typography, card anatomy and how the hand moves**. It also has a state-text trap: labels that describe a state ("Pick a card") stay on screen after the state changed.

## The table

- Background: a vignetted gradient (felt green `Color(0.08, 0.2, 0.16)` to near black at the edges, or a deep purple for fantasy). Draw the vignette as a full-screen `TextureRect` with a radial `GradientTexture2D` (`fill = FILL_RADIAL`, centre transparent, edges `Color(0, 0, 0, 0.55)`).
- Play area in the middle on a rounded, slightly lighter panel with a thin border; each side's zone labelled quietly (small caps, low alpha).
- Both sides always show: health as a bar WITH the number, resource (mana / energy) as pips or a number badge, deck and discard counts.
- The enemy is a **portrait**, not a text row: a drawn figure or monster (`references/characters.md`) above its health bar, with its next intent shown as an icon plus a number ("Attack 8").

## Card anatomy (build one `Card` scene/script and reuse it)

- Size ~150x210 px at 1280x720 (about 1/3.4 of the screen height). Rounded corners 10-12, 2 px border in the type colour, drop shadow (a darker copy offset by 4 px).
- Header band in the type colour (attack red, defence blue, skill green, power purple) with the name (16-18 px, outlined if the band is light).
- Cost badge: a circle in the top-left corner, a contrasting number inside. Art window: a drawn icon (sword, shield, flame) from polygons, centred.
- Body text 14-16 px, dark on a light parchment (contrast 4.5:1) or light on a dark card; never longer than 3 short lines. Type line in small caps at the bottom.
- Unplayable cards (not enough energy) are desaturated and dimmed to 55%; playable ones have a faint glow in the type colour.

## The hand

```gdscript
# Fan the hand along an arc; n cards, index i.
func layout_hand() -> void:
	var n := hand.size()
	var center := Vector2(size.x * 0.5, size.y - 90.0)
	for i in n:
		var t := 0.0 if n == 1 else float(i) / float(n - 1) - 0.5      # -0.5 .. 0.5
		var target_pos := center + Vector2(t * min(n * 120.0, 760.0), abs(t) * abs(t) * 90.0)
		var target_rot := t * 0.32
		var tw := hand[i].create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(hand[i], "position", target_pos, 0.25)
		tw.tween_property(hand[i], "rotation", target_rot, 0.25)
```
- Hover: the card lifts 40 px, straightens (`rotation = 0`), scales to 1.15, `z_index = 10`; neighbours slide sideways 25 px. Drag: follows the mouse with a slight tilt from the velocity; a playable target highlights; dropping outside the play zone tweens back (0.2 s).
- Draw: cards fly from the deck to the hand one by one (0.12 s apart). Play: the card travels to the target, flashes, then dissolves (`modulate.a` to 0 with a scale-down).

## State text without stale labels

- Keep ONE status line and rewrite it on every state change (`_set_status(text)`); keep a single source of truth (`state` enum) and derive labels from it in one `_refresh_ui()` function called after each action. Do not leave "Pick your card" visible during the resolve or result phase (seen in a real run).
- Result banner ("YOU WIN 9 > 4") is its own overlay with a fade-in and a "Next round" button; it must not overlap the played cards.

## Feedback

- Damage: the target shakes 6 px, flashes red, a number floats up; block absorbs with a blue spark. Heal green. Low health: the health bar pulses.
- End turn button: the one primary button, highlighted when no plays are left.

## Checks on the runtime screenshot

- [ ] Cards are large enough to read their text at a glance and never overlap the health or energy displays.
- [ ] The hand is fanned, centred, and fully on screen; hovering (send a mouse move with `send_input`) lifts a card.
- [ ] The enemy has a portrait and a visible intent; both sides show numeric health.
- [ ] No status text is out of date after playing a card.
