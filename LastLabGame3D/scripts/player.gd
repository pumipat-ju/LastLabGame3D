extends CharacterBody3D

signal coin_collected

@export_subgroup("Components")
@export var view: Node3D

@export_subgroup("Properties")
@export var movement_speed: float = 250
@export var jump_strength: float = 7
@export var character_scale: Vector3 = Vector3(0.3, 0.3, 0.3) # ปรับขนาดตัวละครที่นี่

var movement_velocity: Vector3
var rotation_direction: float
var gravity: float = 0.0

var previously_floored: bool = false
var jump_single: bool = true
var jump_double: bool = true

var coins: int = 0

@onready var particles_trail = $ParticlesTrail
@onready var sound_footsteps = $SoundFootsteps
@onready var model = $Character
@onready var animation: AnimationPlayer = $Character.find_child("AnimationPlayer", true, false)

# รายชื่อ animation ที่รองรับ
const A_IDLE  = ["CharacterArmature|Idle"]
const A_WALK  = ["CharacterArmature|Run", "CharacterArmature|Walk"]
const A_JUMP  = ["CharacterArmature|Jump"]
const A_FALL  = ["CharacterArmature|Jump_Idle"]
const A_LAND  = ["CharacterArmature|Jump_Land"]

# เอฟเฟกต์ squash & stretch
const STRETCH_JUMP := Vector3(0.5, 1.5, 0.5)
const SQUASH_LAND  := Vector3(1.25, 0.75, 1.25)

func _ready():
	if model:
		model.scale = character_scale

func play_first(list: Array, xfade := 0.1) -> void:
	if animation == null: return
	for n in list:
		if animation.has_animation(n):
			animation.play(n, xfade)
			return

func is_playing_any(list: Array) -> bool:
	if animation == null: return false
	for n in list:
		if animation.current_animation == n: return true
	return false

func _physics_process(delta):

	handle_controls(delta)
	handle_gravity(delta)
	handle_effects(delta)

	var applied_velocity: Vector3
	applied_velocity = velocity.lerp(movement_velocity, delta * 10)
	applied_velocity.y = -gravity
	velocity = applied_velocity
	move_and_slide()

	if Vector2(velocity.z, velocity.x).length() > 0:
		rotation_direction = Vector2(velocity.z, velocity.x).angle()
	rotation.y = lerp_angle(rotation.y, rotation_direction, delta * 10)

	if position.y < -10:
		get_tree().reload_current_scene()

	# รีเซ็ต scale กลับไปที่ character_scale (ไม่ใช่ 1,1,1)
	model.scale = model.scale.lerp(character_scale, delta * 10)

	if is_on_floor() and gravity > 2 and !previously_floored:
		model.scale = character_scale * SQUASH_LAND
		Audio.play("res://sounds/land.ogg")

	previously_floored = is_on_floor()

func handle_effects(delta):
	particles_trail.emitting = false
	sound_footsteps.stream_paused = true

	var on_floor := is_on_floor()
	var horizontal_velocity := Vector2(velocity.x, velocity.z)
	var speed_factor: float = horizontal_velocity.length() / float(movement_speed) / delta

	if on_floor:
		if gravity > 2 and !previously_floored:
			play_first(A_LAND, 0.05)

		if speed_factor > 0.05:
			if !is_playing_any(A_WALK):
				play_first(A_WALK, 0.1)

			if speed_factor > 0.3:
				sound_footsteps.stream_paused = false
				sound_footsteps.pitch_scale = clamp(speed_factor, 0.8, 2.0)

			if speed_factor > 0.75:
				particles_trail.emitting = true
		else:
			if !is_playing_any(A_IDLE):
				play_first(A_IDLE, 0.1)

		if animation:
			animation.speed_scale = clamp(speed_factor, 0.8, 2.0) if is_playing_any(A_WALK) else 1.0
	else:
		if !is_playing_any(A_JUMP) and !is_playing_any(A_FALL):
			play_first(A_JUMP, 0.05)
		elif is_playing_any(A_JUMP):
			play_first(A_FALL, 0.1)

func handle_controls(delta):
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	input = input.rotated(Vector3.UP, view.rotation.y)

	if input.length() > 1:
		input = input.normalized()

	movement_velocity = input * movement_speed * delta

	if Input.is_action_just_pressed("jump"):
		if jump_single or jump_double:
			jump()

func handle_gravity(delta):
	gravity += 25 * delta
	if gravity > 0 and is_on_floor():
		jump_single = true
		gravity = 0

func jump():
	Audio.play("res://sounds/jump.ogg")
	gravity = -jump_strength
	model.scale = character_scale * STRETCH_JUMP
	if jump_single:
		jump_single = false
		jump_double = true
	else:
		jump_double = false

func collect_coin():
	coins += 1
	coin_collected.emit(coins)
