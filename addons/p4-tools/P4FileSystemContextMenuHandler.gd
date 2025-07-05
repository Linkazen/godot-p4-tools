@tool
extends Control

const P4ContextMenuItem = preload("res://addons/p4-tools/P4ContextMenuItem.gd")
const P4Objects = preload("res://addons/p4-tools/P4Objects.gd")

var _context_menus := Dictionary()


func _init(context_menus: Array[P4ContextMenuItem]) -> void:
	set_name("P4FileSystemContextMenuHandler")
	for menu in context_menus:
		_context_menus[menu.id] = menu
	var popup := _menu_popup()
	var file_tree := _file_tree()
	if popup and file_tree:
		popup.about_to_popup.connect(on_context_menu_show.bind(popup, file_tree))
		popup.id_pressed.connect(on_context_menu_pressed.bind(file_tree))


func on_context_menu_show(context_menu: PopupMenu, file_tree: Tree) -> void:
	context_menu.add_separator()
	var current_index := context_menu.get_item_count()
	var selected_files := _collect_files(file_tree)

	for menu_id: int in _context_menus.keys():
		var menu_item: P4ContextMenuItem = _context_menus[menu_id]
		if selected_files.size() != 0:
			context_menu.add_item(menu_item.name, menu_id)
			context_menu.set_item_disabled(current_index, not menu_item.is_enabled.call(selected_files))
			current_index += 1


func on_context_menu_pressed(id: int, file_tree: Tree) -> void:
	if not _context_menus.has(id):
		return
	var menu_item: P4ContextMenuItem = _context_menus[id]
	var selected_files := _collect_files(file_tree)
	menu_item.execute.call(selected_files)


func _collect_files(file_tree: Tree) -> PackedStringArray:
	var selected_files := PackedStringArray()
	
	# Try getting selected files from EditorInterface first
	var selected_paths = EditorInterface.get_selected_paths()
	if selected_paths.size() > 0:
		for path in selected_paths:
			if path.begins_with("res://"):
				selected_files.append(path)
		if selected_files.size() > 0:
			return selected_files
	
	# Fallback to tree selection
	var selected_item := file_tree.get_selected()
	while selected_item:
		var resource_path: String = selected_item.get_metadata(0)
		var item_text: String = selected_item.get_text(0)
		
		# Check if this is a file by looking for file extensions
		if item_text.contains(".") and resource_path.begins_with("res://"):
			# This is likely a file - construct the full path
			var full_file_path = resource_path.path_join(item_text)
			selected_files.append(full_file_path)
		elif resource_path.begins_with("res://") and resource_path != "res://":
			# This is a folder - only add if it doesn't contain a file extension
			if not item_text.contains("."):
				selected_files.append(resource_path)
		
		selected_item = file_tree.get_next_selected(selected_item)
	
	return selected_files


func _file_tree() -> Tree:
	var nodes = P4Objects.find_nodes_by_class(EditorInterface.get_file_system_dock(), "Tree", true)
	if not nodes.is_empty():
		return nodes[-1]
	return null

func _menu_popup() -> PopupMenu:
	var nodes = P4Objects.find_nodes_by_class(EditorInterface.get_file_system_dock(), "PopupMenu", true)
	if not nodes.is_empty():
		return nodes[-1]
	return null
