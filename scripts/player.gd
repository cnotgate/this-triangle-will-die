extends CharacterBody2D

@onready var player_sprite = $Pivot/PlayerSprite
@onready var hurt_timer = $HurtTimer
@onready var blink_timer = $BlinkTimer
@onready var animation_player = $AnimationPlayer
@onready var sword_area = $Pivot/SwordArea
@onready var pivot = $Pivot
# Node Partikel yang baru lu bikin
@onready var parry_particles = $Pivot/ParryParticles 
# Variabel UI
@onready var hp_bar = $UI/HealthBar
@onready var stamina_bar = $UI/StaminaBar

@onready var enemy_overlap_check = $EnemyOverlapCheck

var sudah_ditutup = false

# Variabel Stamina
var max_stamina : float = 100.0
var current_stamina : float = 100.0
var stamina_regen : float = 15.0 # Kecepatan ngisi stamina per detik
var attack_cost = 15.0
var parry_cost = 10.0

enum State { NORMAL, ATTACK, PARRY, DEAD, DODGE }
@export var current_state = State.NORMAL
@onready var death_ui = $DeathUI
var spawn_point : Vector2

# Settingan Dodge
var dodge_speed : float = 800.0
var dodge_duration : float = 0.3
var dodge_timer : float = 0.0
var dodge_cost : float = 20.0
var dodge_dir : float = 1.0

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Load semua gambar
var tex_happy = preload("res://sprites/player/happy.png")
var tex_happy_blink = preload("res://sprites/player/happy_blink.png")
var tex_fierce = preload("res://sprites/player/fierce.png")
var tex_fierce_hurt = preload("res://sprites/player/fierce_hurt.png")
var tex_damage_1 = preload("res://sprites/player/fierce_damage_1.png")
var tex_damage_1_hurt = preload("res://sprites/player/fierce_damage_1_hurt.png")
var tex_damage_2 = preload("res://sprites/player/fierce_damage_2.png")
var tex_damage_2_hurt = preload("res://sprites/player/fierce_damage_2_hurt.png")
var tex_damage_3 = preload("res://sprites/player/fierce_damage_3.png")
var tex_damage_3_hurt = preload("res://sprites/player/fierce_damage_3_hurt.png")
var boss_scene = preload("res://scenes/components/Boss.tscn")

var combat_cooldown = 0.0
var perfect_parry_active = false
# Getter otomatis, is_blocking true selama lagi di state PARRY
var is_blocking:
	get:
		return current_state == State.PARRY

var max_hp = 100
@export var current_hp = 100:
	set(value):
		current_hp = value
		if is_node_ready():
			update_face()

@export var is_hurt = false:
	set(value):
		is_hurt = value
		if is_node_ready():
			update_face()

@export var in_combat = false:
	set(value):
		in_combat = value
		if is_node_ready():
			update_face()

func _ready():
	$"../PintuGerbang/AnimationPlayer".play("tutup")
	spawn_point = global_position # Inget posisi awal pas start
	
	stamina_bar.rounded = false
	hp_bar.rounded = false
	
	reset_blink_timer()
	sword_area.hide()
	parry_particles.emitting = false
	
	# Setup Bar
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	stamina_bar.max_value = max_stamina
	stamina_bar.value = current_stamina
	
	set_collision_mask_value(2, true)

func reset_blink_timer():
	blink_timer.start(randf_range(2.0, 15))
	
func _process(delta):
	if current_state == State.DEAD:
		player_sprite.visible = false
		return 
	current_stamina = move_toward(current_stamina, max_stamina, stamina_regen * delta)
	stamina_bar.value = current_stamina
	
func _physics_process(delta):
	if current_state == State.DEAD:
		player_sprite.visible = false
		return # Stop semua proses kalo lagi mati
	# Kalo lagi combat timer jalan mundur
	if in_combat:
		combat_cooldown -= delta
		if combat_cooldown <= 0.0:
			in_combat = false
			
	match current_state:
		State.NORMAL:
			handle_movement(delta)
			handle_actions()
		State.ATTACK:
			apply_gravity(delta)
			velocity.x = lerp(velocity.x, 0.0, 0.15) # Ngerem pelan
			
			var direction = Input.get_axis("ui_left", "ui_right")
			# Cancel attack kalau ganti arah dadakan
			if (direction < 0 and pivot.scale.x > 0) or (direction > 0 and pivot.scale.x < 0):
				cancel_current_action()
				
			move_and_slide()
			
		State.PARRY:
			apply_gravity(delta)
			
			# Kalau window perfect parry udah lewat (sudah jadi hold block), player boleh jalan
			if not perfect_parry_active:
				handle_movement(delta)
			else:
				# Pas window parry (0.4s), ngerem total
				velocity.x = lerp(velocity.x, 0.0, 0.15)
				move_and_slide()
			
			# SYARAT KELUAR PARRY STATE (Balik Normal)
			# Lu harus lepas tombol parry buat balik normal
			if not Input.is_action_pressed("parry"):
				animation_player.stop()
				sword_area.hide()
				current_state = State.NORMAL
				perfect_parry_active = false
				update_face()
				
		State.DODGE:
			apply_gravity(delta)
			# Paksa player jalan kenceng
			velocity.x = dodge_dir * dodge_speed
			move_and_slide()
			
			# Timer jalan mundur
			if dodge_timer > 0.0:
				dodge_timer -= delta
			else:
				# Kalo timer udah abis cek dulu masih nyangkut musuh ga
				if not enemy_overlap_check.has_overlapping_bodies():
					# Kalo udah clear alias kosong baru udahan dodgenya
					end_dodge()

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

func handle_movement(delta):
	apply_gravity(delta)

	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		if direction < 0: pivot.scale.x = -1
		elif direction > 0: pivot.scale.x = 1
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func handle_actions():
	if Input.is_action_just_pressed("attack") and current_stamina >= attack_cost:
		current_stamina -= attack_cost
		stamina_bar.value = current_stamina
		start_attack()
		
	elif Input.is_action_just_pressed("parry") and current_stamina >= parry_cost:
		start_parry()
		
	elif Input.is_action_just_pressed("dodge") and current_stamina >= dodge_cost:
		start_dodge()

func start_attack():
	combat_cooldown = 3.0
	in_combat = true
	current_state = State.ATTACK
	sword_area.show()
	animation_player.play("attack")

func start_parry():
	combat_cooldown = 3.0
	in_combat = true
	current_state = State.PARRY
	perfect_parry_active = true
	sword_area.show()
	animation_player.play("parry")
	
	# Window parry kemaren req 0.4 detik
	await get_tree().create_timer(0.4).timeout
	# Setelah 0.4 detik, perfect parry mati, tapi state tetep PARRY (jadi hold block)
	perfect_parry_active = false

func cancel_current_action():
	animation_player.stop()
	sword_area.hide()
	current_state = State.NORMAL
	perfect_parry_active = false

func update_face():
	var hp_percent = float(current_hp) / float(max_hp)

	if not in_combat:
		if hp_percent > 0.8:
			player_sprite.texture = tex_happy
		else:
			# Tetap babak belur tapi pake sprite biasa ga ada efek marah
			if hp_percent > 0.8: player_sprite.texture = tex_fierce
			elif hp_percent > 0.5: player_sprite.texture = tex_damage_1
			elif hp_percent > 0.25: player_sprite.texture = tex_damage_2
			else: player_sprite.texture = tex_damage_3
		return

	# LOGIKA PAS COMBAT 
	if is_hurt:
		if hp_percent > 0.8: player_sprite.texture = tex_fierce_hurt
		elif hp_percent > 0.5: player_sprite.texture = tex_damage_1_hurt
		elif hp_percent > 0.25: player_sprite.texture = tex_damage_2_hurt
		else: player_sprite.texture = tex_damage_3_hurt
	else:
		if hp_percent > 0.8: player_sprite.texture = tex_fierce
		elif hp_percent > 0.5: player_sprite.texture = tex_damage_1
		elif hp_percent > 0.25: player_sprite.texture = tex_damage_2
		else: player_sprite.texture = tex_damage_3

func take_damage(amount):
	if current_state == State.DEAD: return # Kalo udah mati jangan diproses lagi
	
	if hp_bar:
		hp_bar.value = current_hp
	
	if current_hp <= 0:
		die() # Panggil fungsi mati
	else:
		current_hp -= amount
		hp_bar.value = current_hp # Tambahin baris ini
		in_combat = true
		combat_cooldown = 3.0 
		is_hurt = true
		blink_timer.stop()
		update_face()
		hurt_timer.start(0.2)

func die():
	current_state = State.DEAD
	velocity = Vector2.ZERO
	death_ui.show()
	
	# Kasih jeda biar player bisa merenungi nasibnya
	await get_tree().create_timer(3.0).timeout 
	
	# Reload total satu level
	get_tree().reload_current_scene()
	
func respawn():
	current_hp = max_hp
	if hp_bar:
		hp_bar.value = current_hp
		
	global_position = spawn_point # Balik ke titik awal
	death_ui.hide() # Ilangin popup
	current_state = State.NORMAL # Bisa gerak lagi

func _on_hurt_timer_timeout():
	is_hurt = false
	update_face()

func _on_blink_timer_timeout():
	var hp_percent = float(current_hp) / float(max_hp)
	
	if not in_combat and hp_percent > 0.8:
		player_sprite.texture = tex_happy_blink
		await get_tree().create_timer(0.15).timeout
		if not in_combat: 
			update_face()
			
	reset_blink_timer()

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "attack":
		current_state = State.NORMAL
		sword_area.hide()

func trigger_hitstop():
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0
	
func _on_sword_area_area_entered(area):
	if area.name == "HurtBox" and area.get_parent().is_in_group("gatekeeper") and current_state == State.ATTACK:
		area.get_parent().take_damage(10)
		trigger_hitstop()
		
func receive_attack(amount, attacker):
	# Cari tau musuh ada di kiri atau kanan player (-1 kiri, 1 kanan)
	var dir_to_attacker = sign(attacker.global_position.x - global_position.x)
	if dir_to_attacker == 0:
		dir_to_attacker = 1
		
	# Cek apakah arah hadap player sama dengan arah lokasi musuh
	var is_facing_attacker = (pivot.scale.x == dir_to_attacker)

	# 1. PARRY ONE TAP (Harus dapet window 0.4 detik DAN harus ngadep musuh)
	if perfect_parry_active and is_facing_attacker:
		print("PERFECT PARRY!") 
		parry_particles.restart()
		parry_particles.emitting = true 
		trigger_hitstop()
		
		if attacker.has_method("get_parried"):
			attacker.get_parried()
		elif attacker.get_parent().has_method("get_parried"):
			attacker.get_parent().get_parried()
			
	# 2. BLOCK BIASA (Hold tombol DAN harus ngadep musuh)
	elif current_state == State.PARRY and is_facing_attacker:
		print("Nangkis biasa (Hold)")
		current_stamina -= parry_cost
		stamina_bar.value = current_stamina
		take_damage(amount * 0.2)
		
	# 3. KENA PUKUL (Telat parry ATAU lagi ngebelakangin musuh)
	else:
		print("Telak gara gara ngebelakangin musuh!")
		take_damage(amount)

func start_dodge():
	player_sprite.self_modulate.a = 0.7
	current_state = State.DODGE
	current_stamina -= dodge_cost
	if stamina_bar:
		stamina_bar.value = current_stamina
	
	dodge_timer = dodge_duration
	
	# Nentuin arah dodge sesuai arah player ngadep (dari scale pivot)
	if pivot.scale.x > 0:
		dodge_dir = 1.0
	else:
		dodge_dir = -1.0
		
	# BIKIN KEBAl DAN NEMBUS MUSUH
	# Matiin sensor tabrakan ke Layer Musuh (Layer 2)
	set_collision_mask_value(2, false)
	

func end_dodge():
	player_sprite.self_modulate.a = 1
	current_state = State.NORMAL
	
	# NYALAIN LAGI SENSOR TABRAKANNYA BIKIN BISA KENA HIT LAGI
	set_collision_mask_value(2, true)
	

func _on_gate_closer_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not sudah_ditutup:
		$"../PintuGerbang/AnimationPlayer".play("tutup")
		sudah_ditutup = true
		
		var boss_baru = boss_scene.instantiate()
		boss_baru.global_position = $"../BossSpawnPoint".global_position
		boss_baru.scale = Vector2(0.275, 0.275)
		
		get_parent().add_child(boss_baru)
		
		print("Gerbang ditutup dan Bos berhasil di-spawn!")

func _on_sword_area_body_entered(body):
	# Cek apakah badannya punya fungsi take_damage
	if body.has_method("take_damage") and body.name=="Boss" and current_state == State.ATTACK:
		body.take_damage(5)
		trigger_hitstop()
