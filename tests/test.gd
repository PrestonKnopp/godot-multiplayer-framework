# test.gd
extends SceneTree


var time = 0


func _initialize():
	var client = preload('../Multiplayer/MultiplayerHost.gd').new()
	get_root().add_child(client)
	client.start()

func _iteration(delta):
	time += delta
	if time < 10:
		return
	time = 0
	var client = get_root().get_child(0)
	client.registry.set_peer_data(1, 'hello/world', 'ThisHelloWorldString')
	client.registry.set_peer_data(1, 'hello/world/buttface', 'ThisHelloWorldString')
	print('Registry:\n', client.registry.registered)
