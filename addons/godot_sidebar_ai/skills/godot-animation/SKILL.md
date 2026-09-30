---
name: godot-animation
description: Animate things in a Godot 4 game - bobbing, fading, popping, walk cycles, door and UI animations, state-driven character animation. Use when the task needs movement over time: choose between Tween, AnimationPlayer (clips written into the .tscn) and AnimationTree, and verify the result in the running game.
---

# Godot animation

## Choose the method

| Need | Use |
|---|---|
| One-off motion started from code (pop on hit, fade out, slide a panel, count up a score) | `Tween` from `create_tween()` |
| A reusable named clip (door opens, idle bob, walk cycle, attack, UI intro) that you can also see in the editor | `AnimationPlayer` with clips written into the `.tscn` |
| Blending or switching clips by state (idle, run, jump) | `AnimationTree` with a state machine, driven by a few parameters |

Start with Tween for juice and AnimationPlayer for anything named and reused. Add AnimationTree only when there are three or more clips with transitions.

## Tween (code)

```gdscript
var tw := create_tween()
tw.tween_property($Sprite2D, "scale", Vector2(1.3, 1.3), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
tw.tween_property($Sprite2D, "scale", Vector2.ONE, 0.12)
tw.tween_callback(queue_free)                       # runs after the steps above
# parallel steps: tw.set_parallel(true); a nested property path works: "modulate:a"
```

Kill the old tween before starting a new one on the same property (`if tween: tween.kill()`), or motions fight. A Tween stops when its node leaves the tree.

## AnimationPlayer clips in the .tscn (verified format, Godot 4)

```
[sub_resource type="Animation" id="Animation_bob"]
resource_name = "bob"
length = 1.0
loop_mode = 1
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Sprite2D:position")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 0.5, 1),
"transitions": PackedFloat32Array(1, 1, 1),
"update": 0,
"values": [Vector2(0, 0), Vector2(0, -10), Vector2(0, 0)]
}

[sub_resource type="AnimationLibrary" id="AnimationLibrary_main"]
_data = {
&"bob": SubResource("Animation_bob")
}

[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
libraries/ = SubResource("AnimationLibrary_main")
autoplay = &"bob"
```

- The track path is relative to the AnimationPlayer's parent: `"Sprite2D:position"`, `"Door:rotation_degrees"`, `"Panel:modulate"`, `"."` for the root node itself.
- `loop_mode = 1` loops (0 once, 2 ping-pong). `update = 0` interpolates continuously, `1` jumps at the key (use it for visibility, texture, frame).
- One `tracks/N/` block per property; a clip can animate many nodes. Times in seconds, one value per time.
- A call track runs a method at a moment (footstep sound, spawn a bullet): `tracks/1/type = "method"`, path `NodePath(".")` (the node that owns the method), `keys = {"times": PackedFloat32Array(0.5), "transitions": PackedFloat32Array(1), "values": [{"args": [], "method": &"hit"}]}`. Method calls happen in real time while playing, not when you only seek.
- Many clips: add more `&"name": SubResource(...)` lines to the library. A 3D `position` or `rotation_degrees` track works the same way.

Generating many similar clips from code is fine: build an `Animation` (`add_track`, `track_set_path`, `track_insert_key`), put it in an `AnimationLibrary`, `add_animation_library(&"", lib)`, then save the scene with `ResourceSaver`. Saving a real scene once is the safest way to see the exact text.

Play from code: `$AnimationPlayer.play("bob")`, `await $AnimationPlayer.animation_finished`, `play_backwards`, `speed_scale`. After `play()`, `pause()` and `seek(t, true)` show a pose (for checking a frame).

## AnimationTree state machine (code)

```gdscript
var tree := AnimationTree.new()
var sm := AnimationNodeStateMachine.new()
for state in ["idle", "run", "jump"]:
	var node := AnimationNodeAnimation.new()
	node.animation = state
	sm.add_node(state, node)
sm.add_transition("idle", "run", AnimationNodeStateMachineTransition.new())
sm.add_transition("run", "idle", AnimationNodeStateMachineTransition.new())
tree.tree_root = sm
add_child(tree)
tree.anim_player = tree.get_path_to($AnimationPlayer)
tree.active = true
var playback: AnimationNodeStateMachinePlayback = tree.get("parameters/playback")
playback.travel("run")          # follows the transitions; call it from input as needed
```

`travel` only follows transitions that exist, so add them in both directions you need. The clips themselves live in the AnimationPlayer the tree points to.

## Verify (do not stop at "it compiles")

1. `validate_project`, then `play_game`, wait a second, `get_runtime_errors`.
2. `inspect_runtime_node` on the AnimationPlayer: the current animation should be the clip you expect and it should be playing; on the animated node read the property (position, modulate) twice a moment apart: it must change.
3. `take_runtime_screenshot` at a moment where the motion is visible. A clip that plays but moves nothing usually has a wrong track path (the node name or the relative path).
4. Loops: the last key should equal the first. Hit feedback: keep it under 0.2 s.

Common mistakes: path relative to the wrong node; a Tween on a node that is freed; two tweens on one property; forgetting `loop_mode`; expecting `autoplay` to run in the editor (it runs in the game).
