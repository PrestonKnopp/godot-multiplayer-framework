# Multiplayer.gd, abstract and factory
extends Node


# ------------------------------------------------------------------------------
#                                   Inner Classes
# ------------------------------------------------------------------------------


class ObjectIndexPathMap:
	var objects = []
	var index = {}

	func echo(indent=0):
		"""
		Print the structure of this ObjectIndexPathMap.
		"""
		var dent = ''
		for i in indent:
			dent += ' '
		for k in index:
			print(dent, '== %s ==' % k)
			print(dent, '- ', index[k].objects)
			index[k].echo(indent + 2)

	func lookup(indices):
		"""
		Lookup objects that match indices path.

		@indices An Array Type
		    - Indices that form a path, similar to NodePath's names.
		    - Does not use '*' wildcard. It will add undesired objects
		      to the returned pool.
		"""
		return _lookup(indices, indices.size(), 0, [])

	func _lookup(indices, size, idx, __objects):
		"""
		Lookup implementation.
		"""
		if idx >= size:
			return __objects + objects
		var front = indices[idx]
		if index.has('*'):
			__objects = index['*']._lookup(indices, size, idx + 1, __objects)
		if index.has(front):
			return index[front]._lookup(indices, size, idx + 1, __objects)
		return __objects + objects

	func add(indices, object):
		"""
		Add an object to be found when lookup matches with index.

		@indices An Array Type
		    - Indices that form a path, similar to NodePath's names.
		    - An index can be any hashable type.
		    - A special index, a '*' string, is a wildcard. It matches
		      any index at the position of the star. The wildcard is
		      only used for adding. Cannot be used for lookup.
		    - Examples:
			- [*,one] will match:
			    - key/one
			    - ace/one
			    - two/one
			  but will not match:
			    - key/ace/one
			    - key/two/one
			    - key/two/butt/one
			- [*,*,one] will match:
			    - key/ace/one
			    - key/two/one
			- [one, *] will match everything following one:
			    - one/star/dash
			    - one/baked/apple
			    - one/time/that/only/butts
			- [*] will match everything
		@object Object
		    - The object to be mapped to indices.
		"""
		# assert(typeof(indices) == TYPE_ARRAY)
		var map = self
		for dex in indices:
			if not map.index.has(dex):
				map.index[dex] = get_script().new()
			map = map.index[dex]
		map.objects.append(object)


class Registry extends Node:


	class Undefined:
		extends Reference


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
	#                                  Node Callbacks
	# ------------------------------------------------------------------------------


	func _enter_tree():
		name = get_parent().name + '.Registry'


	# ------------------------------------------------------------------------------
	#                      Making Sure Registry Can Make RPC Calls
	# ------------------------------------------------------------------------------


	func network_peer_added():
		"""
		Call this after you set the SceneTree's network peer.
		"""
		print('Network Peer Added')
		if is_host():
			_connected = true
			flush_queue()
		else:
			# flush_queue when successfully connected to server
			get_tree().connect('connected_to_server', self, '_on_connected_to_server')


	# ------------------------------------------------------------------------------
	#                                   Registration
	# ------------------------------------------------------------------------------


	func register(peer_id):
		# when a new peer is registered
		# send it all other peer data
		if is_host() and peer_id != get_my_id():
			print('Registering From Host')
			for p in registered:
				print('Data For Peer[',p,']')
				rpc_id(peer_id, '__recieve_peer_data', p, registered[p])

		registered[peer_id] = {}


	remote func __recieve_peer_data(peer_id, peer_data):
		# FIXME: ConfigFile is being sent as an empty object
		#        try converting to and from dictionaries
		assert(typeof(peer_data) == TYPE_DICTIONARY)
		print('Receiving Peer Data for peer: ', peer_id)
		print('- Recieved Data: ', peer_data)
		registered[peer_id] = peer_data

		# notifiy observers
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
		if is_host() or _connected:
			rpc('__set_peer_data', peer_id, keypath, data)
		else:
			_data_queue.append({peer_id=peer_id, keypath=keypath, data=data})


	sync func __set_peer_data(peer_id, keypath, data):
		_view(peer_id, keypath, get_peer_data(peer_id, keypath), data)
		registered[peer_id][keypath] = data


	func get_peer_data(peer_id, keypath, default=Undefined.new()):
		assert(peer_id in registered)
		var dict = registered[peer_id]
		return dict[keypath] if dict.has(keypath) else default


	# ------------------------------------------------------------------------------
	#                                  Messaging Host
	# ------------------------------------------------------------------------------


	func is_host():
		return get_tree().is_network_server()

	func host_send(func_name, func_arguments):
		rpc_id(1, func_name, func_arguments)


	func host_set(var_name, var_value):
		rset_id(1, var_name, var_value)


	# ------------------------------------------------------------------------------
	#                         Broadcasting to Registered Peers
	# ------------------------------------------------------------------------------


	func broadcast(func_name, func_arguments, blacklist=[]):
		for peer_id in registered:
			if peer_id in blacklist: continue
			rpc_id(peer_id, func_name, func_arguments)


	func broadcast_set(var_name, var_value, blacklist=[]):
		for peer_id in registered:
			if peer_id in blacklist: continue
			rpc_id(peer_id, var_name, var_value)

	# Queue
	func flush_queue():
		print('Flushing Queue')
		for item in _data_queue:
			print('\t', item)
			set_peer_data(item.peer_id, item.keypath, item.data)

	# Callbacks
	func _on_connected_to_server():
		print(name, ' has connected successfully... flushing queue.')
		_connected = true
		flush_queue()


# ------------------------------------------------------------------------------
#                                      Signals
# ------------------------------------------------------------------------------


signal peers_changed()


# ------------------------------------------------------------------------------
#                                     Constants
# ------------------------------------------------------------------------------


const DEFAULT_PORT = 10320


# ------------------------------------------------------------------------------
#                                Object Composition
# ------------------------------------------------------------------------------


var registry = Registry.new()


# ------------------------------------------------------------------------------
#                                     Variables
# ------------------------------------------------------------------------------


# Port that peer should attempt connection
var port = DEFAULT_PORT


# ------------------------------------------------------------------------------
#                                 Static Functions
# ------------------------------------------------------------------------------


static func make_host():
	return load('Multiplayer/MultiplayerHost.gd').new()


static func make_client():
	return load('Multiplayer/MultiplayerClient.gd').new()


# ------------------------------------------------------------------------------
#                                  Node Callbacks
# ------------------------------------------------------------------------------


func _init():
	name = 'Multiplayer'


func _ready():
	add_child(registry)


func _enter_tree():
	var tree = get_tree()
	tree.connect('network_peer_connected', self, '_on_peer_connected')
	tree.connect('network_peer_disconnected', self, '_on_peer_disconnected')


func _exit_tree():
	var tree = get_tree()
	tree.disconnect('network_peer_connected', self, '_on_peer_connected')
	tree.disconnect('network_peer_disconnected', self, '_on_peer_disconnected')


# ------------------------------------------------------------------------------
#                                     Overrides
# ------------------------------------------------------------------------------


func start():
	# in subclass call super last
	print('Connecting to multiplayer')
	registry.network_peer_added()
	registry.register(registry.get_my_id())
	emit_signal('peers_changed')


# ------------------------------------------------------------------------------
#                              Network Peer Callbacks
# ------------------------------------------------------------------------------


func _on_peer_connected(peer_id):
	print('Peer Connected: ', peer_id)
	registry.register(peer_id)
	emit_signal('peers_changed')


func _on_peer_disconnected(peer_id):
	print('Peer Disconnected: ', peer_id)
	registry.unregister(peer_id)
	emit_signal('peers_changed')
