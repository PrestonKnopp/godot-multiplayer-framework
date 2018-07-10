# Lobby.gd
extends Node


signal prestart(this, connection_type)
signal started(this)


# ------------------------------------------------------------------------------
#                                       Enums
# ------------------------------------------------------------------------------


enum ConnectionType {
	HOST=0, JOIN=1
}


# ------------------------------------------------------------------------------
#                                     Variables
# ------------------------------------------------------------------------------


var multiplayer
var _start_cancelled = false


# ------------------------------------------------------------------------------
#                               Lobby Setup Functions
# ------------------------------------------------------------------------------


func start(connection_type):
	"""
	Make connection type. First calls _prestart to check if can start. And
	to do any setup.
	"""

	# Check start conditions
	_start_cancelled = false
	_prestart(connection_type)
	emit_signal('prestart', self, connection_type)
	if _start_cancelled:
		return FAILED

	var Multiplayer = load('res://Multiplayer.gd')
	match connection_type:
		HOST: _setup_multiplayer(Multiplayer.make_host())
		JOIN: _setup_multiplayer(Multiplayer.make_client())
		_: print('Lobby start received invalid connection_type: ', connection_type)
	
	multiplayer.start()
	_started()
	emit_signal('started', self)
	return OK


func start_cancel():
	"""
	Can only be called in _prestart or a prestart signal.
	"""
	_start_cancelled = true


func start_has_canceled():
	"""
	Can only be called in _prestart or a prestart signal. Check if start has already been canceled.
	"""
	return _start_cancelled


func _setup_multiplayer(mp):
	multiplayer = mp
	add_child(multiplayer)
	multiplayer.connect('peers_changed', self, '_peers_changed')


func _prestart(connection_type):
	"""
	Called by self before starting. Set multiplayer options when this is
	called such as ipaddress and max peers.

	Cancel start by calling start_cancel().
	@Override
	"""
	print('Lobby Prestart')


func _started():
	"""
	Called by self after starting.
	@Override
	"""
	print('Lobby Started')


func _peers_changed():
	"""
	Called by self when peers change.
	@Override
	"""
	print('Lobby Peers Changed')
