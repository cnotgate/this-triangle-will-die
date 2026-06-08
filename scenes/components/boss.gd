extends CharacterBody2D

enum State {CHASE, ATTACK, RECOVER, STUNNED, DEAD}
var current_state = State.CHASE

var max_hp = 300
var current_hp = max_hp
var speed = 150.0
var attack_range = 200

# Damage bos ke player
var attack_damage = 25 

@onready var anim_player = $AnimationPlayer
@onready var health_bar = $"BossLayer/BossHealthBar"
@onready var pivot = $Pivot

@onready var weapon_col = $Pivot/StaticBody2D/WeaponArea/CollisionShape2D

var player = null

func _ready():
	current_hp = max_hp
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	
	player = get_tree().get_first_node_in_group("player")
	
	# Matiin sensor senjata dari awal biar ga nyakitin player pas lagi jalan
	weapon_col.disabled = true

func _physics_process(delta):
	if current_state == State.DEAD or not player:
		return

	match current_state:
		State.CHASE:
			chase_player()
		State.RECOVER, State.STUNNED, State.ATTACK:
			# Pas lagi ancang ancang nyerang istirahat atau pusing bosnya ngerem
			velocity = Vector2.ZERO
			move_and_slide()

func flip_towards_player():
	if player.global_position.x < global_position.x:
		pivot.scale.x = 1
	else:
		pivot.scale.x = -1

func chase_player():
	flip_towards_player()
	
	var distance = global_position.distance_to(player.global_position)
	if distance > attack_range:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
	else:
		start_attack()

func start_attack():
	current_state = State.ATTACK
	velocity = Vector2.ZERO
	
	var random_attack = randi() % 2
	if random_attack == 0:
		anim_player.play("attack_1")
	else:
		anim_player.play("attack_2")
	

func take_damage(amount):
	print(amount)
	if current_state == State.DEAD: return
	
	current_hp -= amount
	if health_bar:
		health_bar.value = current_hp
		
	if current_hp <= 0:
		die()

# Fungsi parry khusus bos
func get_parried():
	print("Bos pusing kena parry!")
	current_state = State.STUNNED
	
	# Berhentiin paksa animasi serangannya
	anim_player.stop() 
	
	# Wajib pake set_deferred biar ga crash pas lagi ngitung fisika tabrakan
	weapon_col.set_deferred("disabled", true) 
	
	# Warna bos jadi kebiruan tanda dia lagi pusing
	modulate = Color(0.5, 0.5, 1.0)
	
	# Kasih efek mental dikit ke belakang pas kena parry
	var knockback_dir = -sign(player.global_position.x - global_position.x)
	if knockback_dir == 0: knockback_dir = 1
	velocity.x = knockback_dir * 150
	move_and_slide()
	
	# Pusing selama 2 detik ngasih window player buat ngehajar bos
	await get_tree().create_timer(2.0).timeout
	
	# Cek dulu siapa tau bosnya udah mati digebukin pas lagi pusing
	if current_state != State.DEAD:
		modulate = Color(1.0, 1.0, 1.0)
		current_state = State.CHASE

func die():
	current_state = State.DEAD
	
	# Biar bosnya ngilang dari layar dan hitboxnya mati
	hide()
	$Pivot/StaticBody2D/WeaponArea/CollisionShape2D.set_deferred("disabled", true)
	
	await get_tree().create_timer(1.5).timeout
	
	# Pindah ke scene WIN sesuai request lu
	get_tree().change_scene_to_file("res://scenes/levels/WIN.tscn")
	
	# Baru deh nodenya beneran dihapus dari memori
	queue_free()

func _on_weapon_area_body_entered(body):
	if body.is_in_group("player") and body.has_method("receive_attack"):
		body.receive_attack(attack_damage, self)

func _on_animation_player_animation_finished(anim_name):
	# Kalo animasinya berhenti gara gara di-parry jangan lanjut ke fase recover
	if current_state == State.STUNNED: return
	
	if anim_name == "attack_1" or anim_name == "attack_2":
		current_state = State.RECOVER
		
		# Matiin hitbox senjata pas kelar ngayun
		weapon_col.set_deferred("disabled", true) 
		
		# Jeda 1.2 detik sebelum ngejar lagi
		await get_tree().create_timer(1.2).timeout
		
		# Pastiin bosnya ga lagi pusing atau mati sebelum lanjut ngejar
		if current_state != State.DEAD and current_state != State.STUNNED:
			current_state = State.CHASE
