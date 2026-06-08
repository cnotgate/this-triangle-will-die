extends CharacterBody2D

const SPEED = 70.0
const LUNGE_SPEED = 400.0
const LUNGE_DURATION = 0.4

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var max_hp = 25
var current_hp = max_hp
var player = null

enum State { CHASE, PREPARE_ATTACK, ATTACKING, RECOVER, STUNNED }
var current_state = State.CHASE

var attack_range = 250
var attack_damage = 10
var lunge_dir = 1.0
var lunge_timer = 0.0

@onready var sword_col = $SwordArea/CollisionShape2D
@onready var body = $Polygon2D
var original_color: Color

func _ready():
	$ProgressBar.max_value = max_hp
	$ProgressBar.value = current_hp
	player = get_tree().get_first_node_in_group("player")
	sword_col.disabled = true
	
	original_color = body.color 

func _physics_process(delta):
	$ProgressBar.value = current_hp
	if not is_on_floor():
		velocity.y += gravity * delta
		
	match current_state:
		State.CHASE:
			if player != null:
				var dist = global_position.distance_to(player.global_position)

				if dist <= attack_range:
					start_attack()
				else:
					var direction = sign(player.global_position.x - global_position.x)
					velocity.x = direction * SPEED
					
					if direction != 0:
						$SwordArea.scale.x = direction
						
		State.PREPARE_ATTACK:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			
		State.ATTACKING:
			velocity.x = lunge_dir * LUNGE_SPEED
			
			lunge_timer -= delta
			if lunge_timer <= 0.0:
				end_attack()
				
		State.RECOVER, State.STUNNED:
			# Diam saat attack window
			velocity.x = move_toward(velocity.x, 0, SPEED)
			
	move_and_slide()

func start_attack():
	current_state = State.PREPARE_ATTACK
	
	# Lock arah pas mulai windup
	if player:
		lunge_dir = sign(player.global_position.x - global_position.x)
		if lunge_dir == 0:
			lunge_dir = 1.0
		$SwordArea.scale.x = lunge_dir
	
	# Ubah warna jadi kuning buat windup
	body.color = Color(1.0, 1.0, 0.4) 
	
	# windup
	await get_tree().create_timer(0.8).timeout
	
	# Cancel kalo keburu di-parry/dipukul pas windup
	if current_state != State.PREPARE_ATTACK: return 
	
	current_state = State.ATTACKING
	body.color = Color(1.0, 0.2, 0.2) # Merah pas nyerang
	sword_col.disabled = false # Hitbox aktif
	lunge_timer = LUNGE_DURATION

func end_attack():
	# Matiin hitbox tabrakan
	sword_col.set_deferred("disabled", true)
	
	# Musuh attack window abis menyerang
	current_state = State.RECOVER
	body.color = original_color
	
	# Cooldown 1.2 detik sebelum ngejar lagi
	await get_tree().create_timer(1.2).timeout
	
	if current_state == State.RECOVER:
		current_state = State.CHASE

func _on_sword_area_body_entered(body):
	if body.is_in_group("player") and body.has_method("receive_attack"):
		body.receive_attack(attack_damage, self)

func take_damage(amount):
	current_hp -= amount
	print("Diamond Enemy kena hit! HP sisa: ", current_hp)
	if current_hp <= 0:
		queue_free()

func get_parried():
	print("Diamond Enemy kena parry pas nerjang!")
	current_state = State.STUNNED
	sword_col.set_deferred("disabled", true)
	
	# Warna biru pas kena parry
	body.color = Color(0.6, 0.6, 1.0)
	
	# Mental ke belakang dikit
	var knockback_dir = -sign(player.global_position.x - global_position.x)
	if knockback_dir == 0: knockback_dir = 1
	velocity.x = knockback_dir * 250
	velocity.y = -100
	
	# Stunned 2.5 detik pas kena parry
	await get_tree().create_timer(2.5).timeout
	
	if is_instance_valid(self):
		body.color = original_color
		current_state = State.CHASE
