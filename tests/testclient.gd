# testclient.gd
extends SceneTree


func _initialize():
	var client = preload('../Multiplayer/MultiplayerClient.gd').new()
	get_root().add_child(client)
	client.start()

var time = 0

func _iteration(delta):
	time += delta
	if time < 10:
		return
	time = 0
	var client = get_root().get_child(0)
	print('Registry:\n', client.registry.registered)
