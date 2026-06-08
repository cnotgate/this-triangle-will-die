extends CharacterBody2D

const SPEED = 100.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var max_hp = 50
var current_hp = max_hp
var player = null

# Ini otak FSM nya bro
enum State { CHASE, PREPARE_ATTACK, ATTACKING, STUNNED }
var current_state = State.CHASE

var attack_range = 100 # Jarak dia mulai ngayun pedang
var attack_damage = 15

@onready var sword_col = $SwordArea/CollisionShape2D

func _ready():
	$"./ProgressBar".value = current_hp
	player = get_tree().get_first_node_in_group("player")
	sword_col.disabled = true

func _physics_process(delta):
	$"./ProgressBar".value = current_hp
	if not is_on_floor():
		velocity.y += gravity * delta
		
	match current_state:
		State.CHASE:
			if player != null:
				var dist = global_position.distance_to(player.global_position)
				
				# Kalo udah masuk jarak tebas, mulai nyerang
				if dist <= attack_range:
					start_attack()
				else:
					# Kalo masih jauh, kejar terus
					var direction = sign(player.global_position.x - global_position.x)
					velocity.x = direction * SPEED
					
					# Bikin pedangnya selalu madap ke arah player
					if direction != 0:
						$SwordArea.scale.x = direction
						
		State.PREPARE_ATTACK, State.ATTACKING, State.STUNNED:
			# Pas lagi ancang ancang, nyerang, atau pusing, musuhnya ngerem
			velocity.x = move_toward(velocity.x, 0, SPEED)
			
	move_and_slide()

func start_attack():
	current_state = State.PREPARE_ATTACK
	
	modulate = Color(1.0, 0.5, 0.5)
	await get_tree().create_timer(0.4).timeout
	
	# Batalin serangan kalo musuh keburu mati atau di-parry pas ancang-ancang
	if current_state != State.PREPARE_ATTACK: return 
	
	# NEBAS!
	current_state = State.ATTACKING
	modulate = Color(1.0, 0.0, 0.0) # Merah gelap
	sword_col.disabled = false # Hitbox pedang nyala
	
	await get_tree().create_timer(0.2).timeout # Durasi pedang aktif
	sword_col.disabled = true # Hitbox mati lagi
	
	# COOLDOWN / RECOVERY
	modulate = Color(1.0, 1.0, 1.0) # Balik warna normal
	await get_tree().create_timer(1.0).timeout # Musuh bengong 1 detik abis nyerang
	
	if current_state == State.ATTACKING:
		current_state = State.CHASE

func _on_sword_area_body_entered(body):
	if body.is_in_group("player") and body.has_method("receive_attack"):
		body.receive_attack(attack_damage, self)

func take_damage(amount):
	current_hp -= amount
	print("Musuh kena hit! Sisa HP: ", current_hp)
	if current_hp <= 0:
		if $".".is_in_group("gatekeeper"):
			$"../PintuGerbang/AnimationPlayer".play("buka")
		queue_free()

func get_parried():
	print("RectangleEnemy: Kena parry bro pusing gw!")
	current_state = State.STUNNED
	
	# JANGAN PAKE: sword_col.disabled = true
	# PAKE INI BIAR GA ERROR:
	sword_col.set_deferred("disabled", true) 
	
	modulate = Color(0.5, 0.5, 1.0)
	
	var knockback_dir = -sign(player.global_position.x - global_position.x)
	if knockback_dir == 0: knockback_dir = 1
	velocity.x = knockback_dir * 300
	velocity.y = -150 
	
	await get_tree().create_timer(2.0).timeout
	
	if is_instance_valid(self):
		modulate = Color(1.0, 1.0, 1.0)
		current_state = State.CHASE
	
	# Pusing selama 2 detik
	await get_tree().create_timer(2.0).timeout
	
	if is_instance_valid(self): # Cek takutnya dia udah mati pas lagi pusing
		modulate = Color(1.0, 1.0, 1.0)
		current_state = State.CHASE
