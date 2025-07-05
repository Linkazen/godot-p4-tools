class_name P4Objects
extends Resource

static func find_nodes_by_class(root: Node, cls: String, recursive: bool = false) -> Array[Node]:
	if not recursive:
		return _find_nodes_by_class_no_rec(root, cls)
	return _find_nodes_by_class(root, cls)


static func _find_nodes_by_class_no_rec(parent: Node, cls: String) -> Array[Node]:
	var result :Array[Node] = []
	for ch in parent.get_children():
		if ch.get_class() == cls:
			result.append(ch)
	return result


static func _find_nodes_by_class(root: Node, cls: String) -> Array[Node]:
	var result :Array[Node] = []
	var stack  :Array[Node] = [root]
	while stack:
		var node :Node = stack.pop_back()
		if node.get_class() == cls:
			result.append(node)
		for ch in node.get_children():
			stack.push_back(ch)
	return result
