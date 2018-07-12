# Lobby.gd
extends Node


signal prestart(this, connection_type)
signal started(this)


# ------------------------------------------------------------------------------
#                                       Types
# ------------------------------------------------------------------------------


const MultiplayerScene = preload('../Multiplayer.tscn')


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
	
	multiplayer = MultiplayerScene.instance()
	
	# Check start conditions
	_start_cancelled = false
	_prestart(connection_type)
	emit_signal('prestart', self, connection_type)
	if _start_cancelled:
		multiplayer.free()
		multiplayer = null
		return FAILED
	
	add_child(multiplayer)
	multiplayer.connect('peers_changed', self, '_peers_changed')
	multiplayer.start(connection_type)
	
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


func _peers_changed(multiplayer):
	"""
	Called by self when peers change.
	@Override
	"""
	print('Lobby Peers Changed')
