# Multiplayer.gd, abstract and factory
extends Node


# ------------------------------------------------------------------------------
#                                   Inner Classes
# ------------------------------------------------------------------------------


class Registry extends Node:


	class Undefined extends Object:
		var undef = true
	

	# dict with format {peer_id : peer_data}
	var registered = {}
	# dict with format
	var _observers = {
		observers = [],
		peer_ids = {},
		sections = {},
		keys = {}
	}
	# only used for client when it hasn't connected to host
#	var _my_data_dirty = false
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
				echo_cfg(get_peer_data(p))
				rpc_id(peer_id, '__recieve_peer_data', p, get_peer_data(p))

		registered[peer_id] = ConfigFile.new()
	

	remote func __recieve_peer_data(peer_id, peer_data):
		# FIXME: ConfigFile is being sent as an empty object
		#        try converting to and from dictionaries
		print('Receiving Peer Data for peer: ', peer_id)
		assert(peer_data is ConfigFile)
		echo_cfg(peer_data)
		registered[peer_id] = peer_data


	func unregister(peer_id):
		registered.erase(peer_id)


	# ------------------------------------------------------------------------------
	#                                        Me
	# ------------------------------------------------------------------------------


	func set_my_data(section, key, data):
		set_peer_data(get_my_id(), section, key, data)


	func get_my_data():
		return registered[get_my_id()]


	func get_my_id():
		return get_tree().network_peer.get_unique_id()


	# ------------------------------------------------------------------------------
	#                                     Peer Data
	# ------------------------------------------------------------------------------

	
	# -- Observer

	func observe(obj, fun, peer_id=null, section=null, key=null):
		"""
		Observer function will be passed: this, peer_id, section, and
		key.
		"""
		# At least one optional arg must be specified
		assert(!(peer_id == null and section == null and key == null))

		var topic_dict = _observers
		var topics = [peer_id, section, key]
		var topic_keys = ['peer_ids', 'sections', 'keys']
		for i in topics.size():
			var topic = topics[i]
			var topic_key = topic_keys[i]
			if topic == null: continue
			if not topic_dict[topic_key].has(topic):
				topic_dict[topic_key][topic] = {
					observers = []
				}
				for j in range(i + 1, topics.size()):
					topic_dict[topic_key][topic][topic_keys[j]] = {
						observers = []
					}
			topic_dict = topic_dict[topic_key][topic]

			var nonnull_topic_exists = false
			for j in range(i + 1, topics.size()):
				if topics[j] != null:
					nonnull_topic_exists = true
					break
			if not nonnull_topic_exists:
				topic_dict['observers'].append(funcref(obj, fun))
	

	func echo_cfg(d):
		for s in d.get_sections():
			for k in d.get_section_keys(s):
				print('\t%s.%s: %s' % [s,k,d.get_value(s,k)])


	func echo_dict(d, indent=0):
		var dent = ''
		for i in indent:
			dent += ' '
		var s = ''
		for k in d:
			s = '%s%s: ' % [dent, k]
			if typeof(d[k]) == TYPE_DICTIONARY:
				s += '{'
				print(s)
				echo_dict(d[k], indent + 2)
				print(dent, '}')
			else:
				s += str(d[k])
				print(s)


	func _view(peer_id, section, key, data_old, data_new):
		var tdict = _observers
		var topics = [peer_id, section, key]
		var topic_keys = ['peer_ids', 'sections', 'keys']
		for i in topics.size():
			var t = topics[i]
			var tkey = topic_keys[i]
			if t == null: continue
			if tdict.has(tkey) and tdict[tkey].has(t):
				tdict = tdict[tkey][t]

		if tdict.has('observers'):
			for observer in tdict['observers']:
				observer.call_func(self, peer_id, section, key, data_old, data_new)

	# -- End Observer


	func set_peer_data(peer_id, section, key, data):
		""" synced """
		assert(peer_id != null)
		assert(section != null and typeof(section) == TYPE_STRING)
		assert(key != null and typeof(key) == TYPE_STRING)
		if is_host() or _connected:
			rpc('__set_peer_data', peer_id, section, key, data)
		else:
			_data_queue.append({peer_id=peer_id, section=section, key=key, data=data})


	sync func __set_peer_data(peer_id, section, key, data):
		var cfg = registered[peer_id]
		_view(peer_id, section, key, cfg.get_value(section, key, Undefined.new()), data)
		cfg.set_value(section, key, data)


	func get_peer_data(peer_id):
		assert(peer_id in registered)
		return registered[peer_id]


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
			set_peer_data(item.peer_id, item.section, item.key, item.data)
	
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
