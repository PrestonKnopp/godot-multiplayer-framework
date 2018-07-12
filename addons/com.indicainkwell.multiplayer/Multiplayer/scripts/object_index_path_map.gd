# object_index_path_map.gd
extends Reference


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

