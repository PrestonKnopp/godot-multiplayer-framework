# MultiplayerClient.gd
extends '../Multiplayer.gd'


# ------------------------------------------------------------------------------
#                                     Constants
# ------------------------------------------------------------------------------


const DEFAULT_IPADDRESS = '127.0.0.1'


# ------------------------------------------------------------------------------
#                                     Variables
# ------------------------------------------------------------------------------


var ipaddress


# ------------------------------------------------------------------------------
#                                  Node Callbacks
# ------------------------------------------------------------------------------


func _ready():
	var tree = get_tree()
	tree.connect('connected_to_server', self, '_on_connected_to_server')
	tree.connect('connection_failed', self, '_on_connect_to_server_failed')
	tree.connect('server_disconnected', self, '_on_server_disconnected')


# ------------------------------------------------------------------------------
#                                     Overriden
# ------------------------------------------------------------------------------


func start():
	var peer = NetworkedMultiplayerENet.new()
	var address = ipaddress if ipaddress != null else DEFAULT_IPADDRESS
	var port_ = port if port != null else DEFAULT_PORT
	peer.create_client(address, port_)
	get_tree().network_peer = peer
	.start()


# ------------------------------------------------------------------------------
#                         Multiplayer Connection Callbacks
# ------------------------------------------------------------------------------


func _on_connected_to_server():
	print('Successfully connected to server')


func _on_connect_to_server_failed():
	print('Failed to connect to server')


func _on_server_disconnected():
	print('Server disconnected')
