# Registry.gd
extends Node


# ------------------------------------------------------------------------------
#                                       Types
# ------------------------------------------------------------------------------


const ObjectIndexPathMap = preload('scripts/object_index_path_map.gd')


class Undefined:
	extends Reference


# ------------------------------------------------------------------------------
#                                     Variables
# ------------------------------------------------------------------------------


# Used to represent peer data that has not been defined yet
var UNDEFINED = Undefined.new() setget ,get_undefined
func get_undefined(): return UNDEFINED


# dict with format {peer_id : peer_data}
var registered = {}
# map of peer_data paths to observers
var _observer_map = ObjectIndexPathMap.new()

# only used for client when it hasn't connected to host
var _data_queue = []
var _connected = false


# ------------------------------------------------------------------------------
#                      Making Sure Registry Can Make RPC Calls
# ------------------------------------------------------------------------------


func start(multiplayer):
	"""
	Call this after you set the SceneTree's network peer.
	"""
	register(get_my_id())
	if is_host(): connected()


func stop(multiplayer):
	disconnected()


func connected():
	_connected = true
	flush_queue()


func disconnected():
	_connected = false


# ------------------------------------------------------------------------------
#                                   Registration
# ------------------------------------------------------------------------------


func register(peer_id):
	if is_host() and peer_id != get_my_id():
		print('Registering From Host')
		# when a new peer is registered
		# send it all other peer data
		for p in registered:
			print('Data For Peer[',p,']')
			rpc_id(peer_id, '__register_peer_data', p, registered[p])

	registered[peer_id] = {}


remote func __register_peer_data(peer_id, peer_data):
	assert(typeof(peer_data) == TYPE_DICTIONARY)
	print('Registering Peer Data for peer: ', peer_id)
	print('- Registering Data: ', peer_data)
	registered[peer_id] = peer_data

	# notify observers
	for keypath in peer_data:
		_view(peer_id, keypath, UNDEFINED, peer_data[keypath])	


func unregister(peer_id):
	registered.erase(peer_id)


# ------------------------------------------------------------------------------
#                                        Me
# ------------------------------------------------------------------------------


func set_my_data(keypath, data):
	set_peer_data(get_my_id(), keypath, data)


func get_my_data(keypath, default=UNDEFINED):
	return get_peer_data(get_my_id(), keypath, default)


func get_my_id():
	return get_tree().network_peer.get_unique_id()


# ------------------------------------------------------------------------------
#                                     Peer Data
# ------------------------------------------------------------------------------


# -- Observer

func _make_observe_keypath_indices(peer_id, keypath):
	if peer_id == null:
		peer_id = '*'

	var indices = [peer_id]
	if keypath != null:
		indices += Array(keypath.split('/'))
	return indices


func observe(obj, fun, peer_id=null, keypath=null):
	"""
	Observe data changes sent to peer_id at keypath. If both peer_id
	and keypath are null observer will be notified of all data
	changes.

	Observer function will be passed: this, peer_id, keypath, old
	data, and new data.

	@obj Object
	  The object to call @fun on
	@fun String
	  The function name to call on @obj
	@peer_id int?
	  The optional peer id to specifically observe
	@keypath String?
	  A string path format. i.e. 'my/data/to/track'
	"""
	var indices = _make_observe_keypath_indices(peer_id, keypath)
	_observer_map.add(indices, funcref(obj, fun))


func _view(peer_id, keypath, data_old, data_new):
	var indices = _make_observe_keypath_indices(peer_id, keypath)
	var observers = _observer_map.lookup(indices)
	for observer in observers:
		observer.call_func(self, peer_id, keypath, data_old, data_new)

# -- End Observer


func set_peer_data(peer_id, keypath, data):
	""" synced """
	assert(peer_id != null)
	assert(keypath != null and typeof(keypath) == TYPE_STRING)
	if is_host():
		__receive_peer_data(peer_id, keypath, data)
	elif _connected:
		rpc_id(1, '__receive_peer_data', peer_id, keypath, data)
	else:
		_data_queue.append({peer_id=peer_id, keypath=keypath, data=data})


remote func __receive_peer_data(peer_id, keypath, data):
	_view(peer_id, keypath, get_peer_data(peer_id, keypath), data)
	registered[peer_id][keypath] = data
	if is_host():
		broadcast(self, '__receive_peer_data', [peer_id, keypath, data], [get_my_id()])


func get_peer_data(peer_id, keypath, default=Undefined.new()):
	assert(peer_id in registered)
	var dict = registered[peer_id]
	return dict[keypath] if dict.has(keypath) else default


# ------------------------------------------------------------------------------
#                                  Messaging Host
# ------------------------------------------------------------------------------


func is_host():
	return get_tree().is_network_server()

func host_send(from_obj, to_func, with_arguments=[]):
	var obj = self if from_obj == null else from_obj
	return obj.callv('rpc_id', [1, to_func] + with_arguments)


func host_set(from_obj, var_name, var_value):
	var obj = self if from_obj == null else from_obj
	return obj.rset_id(1, var_name, var_value)


# ------------------------------------------------------------------------------
#                         Broadcasting to Registered Peers
# ------------------------------------------------------------------------------


func broadcast(from_obj, to_func, with_arguments=[], blacklist=[]):
	var obj = self if from_obj == null else from_obj
	for peer_id in registered:
		if peer_id in blacklist: continue
		obj.callv('rpc_id', [peer_id, to_func] + with_arguments)


func broadcast_set(from_obj, var_name, var_value, blacklist=[]):
	var obj = self if from_obj == null else from_obj
	for peer_id in registered:
		if peer_id in blacklist: continue
		obj.rset_id(peer_id, var_name, var_value)

# Queue
func flush_queue():
	print('Flushing Queue:')
	for item in _data_queue:
		print('\t- Item ', item)
		set_peer_data(item.peer_id, item.keypath, item.data)

# Callbacks
func _on_connected_to_server():
	print(name, ' has connected successfully... flushing queue.')
	_connected = true
	flush_queue()

