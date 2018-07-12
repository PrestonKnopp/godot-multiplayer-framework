# Multiplayer.gd, abstract and factory
extends Node


# ------------------------------------------------------------------------------
#                                      Signals
# ------------------------------------------------------------------------------


signal peers_changed(this)
signal peer_disconnected(this, peer_id)
signal peer_connected(this, peer_id)
signal host_disconnected(this)
signal connection_success(this)
signal connection_failed(this)


# ------------------------------------------------------------------------------
#                                     Constants
# ------------------------------------------------------------------------------


const DEFAULT_PORT = 10320
const DEFAULT_IPADDRESS = '127.0.0.1'
const DEFAULT_MAX_PEERS = 32


# ------------------------------------------------------------------------------
#                                       Enums
# ------------------------------------------------------------------------------


enum MultiplayerConnection {
	NONE=0, HOST=1, JOIN=2
}


# ------------------------------------------------------------------------------
#                                      Exports
# ------------------------------------------------------------------------------


export(int) var max_peers = DEFAULT_MAX_PEERS
export(int) var port = DEFAULT_PORT
export(String) var ipaddress = DEFAULT_IPADDRESS


# ------------------------------------------------------------------------------
#                                      SetGets
# ------------------------------------------------------------------------------


var registry setget ,get_registry
func get_registry():
	return get_node('Registry')


var network_starter setget ,get_network_starter
func get_network_starter():
	return get_node('NetworkStarter')


var connection = NONE setget ,get_connection
func get_connection():
	return connection


# ------------------------------------------------------------------------------
#                                  Node Callbacks
# ------------------------------------------------------------------------------


func _enter_tree():
	var tree = get_tree()
	tree.connect('network_peer_connected', self, '_on_peer_connected')
	tree.connect('network_peer_disconnected', self, '_on_peer_disconnected')
	tree.connect('connected_to_server', self, '_on_connected_to_host')
	tree.connect('connection_failed', self, '_on_connection_to_host_failed')
	tree.connect('server_disconnected', self, '_on_host_disconnected')


func _exit_tree():
	var tree = get_tree()
	tree.disconnect('network_peer_connected', self, '_on_peer_connected')
	tree.disconnect('network_peer_disconnected', self, '_on_peer_disconnected')
	tree.disconnect('connected_to_server', self, '_on_connected_to_host')
	tree.disconnect('connection_failed', self, '_on_connection_to_host_failed')
	tree.disconnect('server_disconnected', self, '_on_host_disconnected')


# ------------------------------------------------------------------------------
#                                      Methods
# ------------------------------------------------------------------------------


func start(with_connection):
	assert(with_connection in [HOST, JOIN])
	connection = with_connection
	self.network_starter.start(self)
	self.registry.start(self)
	emit_signal('peers_changed', self)


func stop():
	connection = NONE
	self.network_starter.stop(self)
	self.registry.stop(self)


# ------------------------------------------------------------------------------
#                              Network Peer Callbacks
# ------------------------------------------------------------------------------


# -- client peers


func _on_connected_to_host():
	print('Successfully connected to Host')
	self.registry.connected()
	emit_signal('connection_success', self)


func _on_connection_to_host_failed():
	print('Failed to connect to Host')
	self.registry.disconnected()
	emit_signal('connection_failed', self)


func _on_host_disconnected():
	print('Host disconnected')
	self.registry.disconnected()
	emit_signal('host_disconnected', self)


# -- all peers


func _on_peer_connected(peer_id):
	print('Peer Connected: ', peer_id)
	self.registry.register(peer_id)
	emit_signal('peers_changed', self)
	emit_signal('peer_connected', self, peer_id)


func _on_peer_disconnected(peer_id):
	print('Peer Disconnected: ', peer_id)
	self.registry.unregister(peer_id)
	emit_signal('peers_changed', self)
	emit_signal('peer_disconnected', self, peer_id)
