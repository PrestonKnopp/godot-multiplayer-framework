# Lobby.gd
extends Node


# ------------------------------------------------------------------------------
#                                     Variables
# ------------------------------------------------------------------------------


var multiplayer


# ------------------------------------------------------------------------------
#                               Lobby Setup Functions
# ------------------------------------------------------------------------------


func setup_multiplayer(multiplayer):
	add_child(multiplayer)
	multiplayer.connect('peers_changed', self, 'refresh')
	multiplayer.start()


func host():
	multiplayer = load('res://Multiplayer.gd').make_host()
	setup_multiplayer(multiplayer)


func join():
	multiplayer = load('res://Multiplayer.gd').make_client()
	setup_multiplayer(multiplayer)


func refresh():
	# override
	pass
