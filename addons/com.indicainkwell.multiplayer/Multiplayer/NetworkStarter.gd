# NetworkStarter.gd
extends Node


# ------------------------------------------------------------------------------
#                                      Signals
# ------------------------------------------------------------------------------


signal network_peer_created(this, peer)
signal network_peer_added(this, peer)

signal network_peer_error(this, peer, error)


# ------------------------------------------------------------------------------
#                                      SetGets
# ------------------------------------------------------------------------------


var peer setget ,get_peer
func get_peer():
	return get_tree().network_peer


# ------------------------------------------------------------------------------
#                                      Methods
# ------------------------------------------------------------------------------


func start(multiplayer):
	assert(is_inside_tree())

	if get_peer() != null:
		stop(multiplayer)

	var error = OK
	var peer = NetworkedMultiplayerENet.new()
	match multiplayer.connection:
		multiplayer.HOST:
			error = peer.create_server(multiplayer.port, multiplayer.max_peers)
		multiplayer.JOIN:
			error = peer.create_client(multiplayer.ipaddress, multiplayer.port)
	
	if error != OK:
		emit_signal('network_peer_error', self, peer, error)
	else:
		emit_signal('network_peer_created', self, peer)
		get_tree().network_peer = peer
		emit_signal('network_peer_added', self, peer)
	return error


func stop(multiplayer):
	get_peer().close_connection()
