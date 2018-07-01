extends 'Lobby.gd'

# TODO: write custom lobby and gameplay setup that loosely resembles age of
# empires' lobby.


func _ready():
	refresh()


func valid():
	if $ui/VBoxContainer/username.text == '':
		show_error('Invalid Username')
		return false
	$ui/VBoxContainer/username.editable = false
	return true


func _update_my_data():
	multiplayer.registry.observe(self, '_on_user_data', null, 'user')
	multiplayer.registry.set_my_data('user/name', $ui/VBoxContainer/username.text)
	multiplayer.registry.set_my_data('user/ready', false)
	call_deferred('refresh')


func host():
	if not valid(): return
	.host()
	_update_my_data()


func join():
	if not valid(): return
	.join()
	_update_my_data()


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
