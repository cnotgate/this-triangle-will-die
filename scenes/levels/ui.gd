extends Control

func _on_play_pressed():
	# Jangan lupa ganti nama file tscn di bawah ini sama nama scene level utama lu
	get_tree().change_scene_to_file("res://scenes/levels/level1.tscn")

func _on_quit_pressed():
	# Kodingan buat nutup game
	get_tree().quit()
