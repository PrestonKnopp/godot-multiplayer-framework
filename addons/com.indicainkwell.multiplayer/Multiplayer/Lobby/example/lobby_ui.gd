extends '../Lobby.gd'

signal start_game(this)

var players_ready = []


func _ready():
	refresh()


func _peers_changed(multiplayer):
	refresh()


func _prestart(connection_type):
	if $ui/VBoxContainer/username.text == '':
		show_error('Invalid Username')
		start_cancel()
	else:
		$ui/VBoxContainer/username.editable = false
		var ipaddress = $ui/VBoxContainer/HBoxContainer2/ipaddress_line.text
		var port = $ui/VBoxContainer/HBoxContainer2/port_spinbox.value
		if ipaddress.is_valid_ip_address():
			multiplayer.ipaddress = ipaddress
		if port != 0:
			multiplayer.port = port
		print('port: ', multiplayer.port, ', ipaddress: ', multiplayer.ipaddress)


func _started():
	multiplayer.registry.observe(self, '_on_user_data', null, 'user')
	multiplayer.registry.set_my_data('user/name', $ui/VBoxContainer/username.text)
	multiplayer.registry.set_my_data('user/ready', false)


func refresh():
	print('Refreshing')
	var tree = find_node('Tree')
	tree.clear()

	if multiplayer == null:
		return

	var root = tree.create_item()
	root.set_text(0, 'Waiting for Players')


	for peer_id in multiplayer.registry.registered:
		var item = tree.create_item(root)
		
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		if peer_id == multiplayer.registry.get_my_id():
			item.set_editable(0, true)

		var peer_name = multiplayer.registry.get_peer_data(peer_id, 'user/name', peer_id)
		var peer_ready = multiplayer.registry.get_peer_data(peer_id, 'user/ready', false)
		item.set_text(0, str(peer_name))
		item.set_checked(0, peer_ready)
		
		if peer_ready:
			if not players_ready.has(peer_id):
				players_ready.append(peer_id)
		else:
			if players_ready.has(peer_id):
				players_ready.erase(peer_id)
		
		$ui/VBoxContainer/start_butt.disabled = players_ready.size() != multiplayer.registry.registered.size() or players_ready.empty() and not multiplayer.registry.is_host()


func show_error(err):
	$ui/error.show()
	$ui/error/Label.text = err
	$ui/error/Timer.start()


func _on_tree_item_edited():
	var edited = find_node('Tree').get_edited()
	print('item edited', edited)
	multiplayer.registry.set_my_data('user/ready', edited.is_checked(0))


func _on_user_data(registry, peer_id, keypath, data_old, data_new):
	prints('User Data Changed', peer_id, keypath, data_old, data_new)
	call_deferred('refresh')
	if peer_id == registry.get_my_id():
		return


func _on_start_butt_pressed():
	emit_signal('start_game', self)
