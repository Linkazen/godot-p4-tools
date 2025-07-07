@tool
extends EditorPlugin

const PLUGIN_NAME = "Perforce Integration"

const P4FileSystemContextMenuHandler = preload("res://addons/p4-tools/P4FileSystemContextMenuHandler.gd")
const P4ContextMenuItem = preload("res://addons/p4-tools/P4ContextMenuItem.gd")
const P4Tab = preload("res://addons/p4-tools/p4_tab.tscn")

var file_system: EditorFileSystem
var perforce_client: PerforceClient
var pending_checkouts = []
var _context_menu_handler
var p4_tab_instance

func _enter_tree():
	file_system = EditorInterface.get_resource_filesystem()
	
	# Create Perforce client
	perforce_client = PerforceClient.new()
	perforce_client.file_checked_out.connect(_on_file_checked_out)
	perforce_client.checkout_failed.connect(_on_checkout_failed)
	
	# Connect editor signals
	resource_saved.connect(_on_resource_saved)
	scene_saved.connect(_on_scene_saved)
	scene_changed.connect(_on_scene_changed)
	
	# Hook into the undo/redo system for property changes
	add_undo_redo_inspector_hook_callback(_on_inspector_property_edited)
	
	# Monitor filesystem changes to catch scene saves
	file_system.filesystem_changed.connect(_on_filesystem_changed)
	
	# Connect to project run to checkout files before game starts
	if EditorInterface.get_editor_main_screen():
		var editor = EditorInterface.get_editor_main_screen().get_parent()
		if editor and editor.has_signal("project_run_started"):
			editor.project_run_started.connect(_on_project_run_started)
	
	# Add tool menu
	add_tool_menu_item("P4 Checkout Current File", _checkout_current_file)
	add_tool_menu_item("P4 Show Checked Out Files", _show_checked_out_files)
	
	# Create and add P4 tab to dock
	p4_tab_instance = P4Tab.instantiate()
	p4_tab_instance.set_perforce_client(perforce_client)
	add_control_to_dock(DOCK_SLOT_LEFT_BL, p4_tab_instance)
	
	add_file_system_dock_context_menu()

func _exit_tree():
	remove_tool_menu_item("P4 Checkout Current File")
	remove_tool_menu_item("P4 Show Checked Out Files")
	
	# Remove P4 tab from dock
	if p4_tab_instance:
		remove_control_from_docks(p4_tab_instance)
		p4_tab_instance.queue_free()
	if _context_menu_handler:
		remove_child(_context_menu_handler)
		_context_menu_handler.free()

	resource_saved.disconnect(_on_resource_saved)
	scene_saved.disconnect(_on_scene_saved)
	scene_changed.disconnect(_on_scene_changed)
	file_system.filesystem_changed.disconnect(_on_filesystem_changed)
	
	remove_undo_redo_inspector_hook_callback(_on_inspector_property_edited)
	
	# Clean up Perforce client
	if perforce_client:
		perforce_client.file_checked_out.disconnect(_on_file_checked_out)
		perforce_client.checkout_failed.disconnect(_on_checkout_failed)
		perforce_client = null

func add_file_system_dock_context_menu() -> void:
	var is_enabled = func(selected_files: PackedStringArray) -> bool:
		return selected_files.size() > 0

	var checkout_files = func(selected_files: PackedStringArray) -> void:
		for file in selected_files:
			perforce_client.checkout_file(file)

	var menu: Array[P4ContextMenuItem] = [
		P4ContextMenuItem.new(P4ContextMenuItem.MENU_ID.CHECK_OUT, "P4 Checkout", "", func(_f): return true, is_enabled, checkout_files),
	]
	_context_menu_handler = P4FileSystemContextMenuHandler.new(menu)
	add_child(_context_menu_handler)

func _apply_changes():
	# This is called before the editor saves
	if not perforce_client:
		return

	var files_to_process = {}

	# Collect all files that might be saved
	for file_path in pending_checkouts:
		if file_path != "":
			files_to_process[file_path] = true
	
	var edited_scene = EditorInterface.get_edited_scene_root()
	if edited_scene and edited_scene.scene_file_path != "":
		files_to_process[edited_scene.scene_file_path] = true

	for scene_path in EditorInterface.get_open_scenes():
		if scene_path != "":
			files_to_process[scene_path] = true

	var script_editor = EditorInterface.get_script_editor()
	if script_editor:
		for script in script_editor.get_open_scripts():
			if script and script.resource_path != "":
				files_to_process[script.resource_path] = true

	# Also check for any open resources in the inspector
	var inspector = EditorInterface.get_inspector()
	if inspector:
		var edited_object = inspector.get_edited_object()
		if edited_object is Resource and edited_object.resource_path != "":
			files_to_process[edited_object.resource_path] = true

	# Now process the unique list of files
	for file_path in files_to_process.keys():
		if not perforce_client.ensure_checked_out(file_path):
			push_error("P4: Failed to checkout file before save: " + file_path)

	pending_checkouts.clear()
	
	# Clean up old entries periodically
	perforce_client.cleanup_old_entries()

func _save_external_data():
	# Called after save completes
	pass

func _on_inspector_property_edited(undo_redo, object, property, new_value):
	# When a property is edited in inspector, track the resource for checkout
	if object is Resource and object.resource_path != "":
		if not object.resource_path in pending_checkouts:
			pending_checkouts.append(object.resource_path)
	
	# Also check if this is a scene node being edited
	if object is Node:
		var scene_root = object.get_tree().edited_scene_root if object.get_tree() else null
		if scene_root and scene_root.scene_file_path != "":
			if not scene_root.scene_file_path in pending_checkouts:
				pending_checkouts.append(scene_root.scene_file_path)

# Signal handlers for PerforceClient
func _on_file_checked_out(file_path: String, success: bool):
	if success:
		# Force filesystem update
		file_system.scan()
		# Update file in editor if it's currently open
		EditorInterface.reload_scene_from_path(file_path)
		# Refresh the P4 tab to show the newly checked out file
		if p4_tab_instance:
			p4_tab_instance.refresh()
	else:
		push_error("P4: Failed to checkout " + file_path)

func _on_checkout_failed(file_path: String, error_message: String):
	var full_error = "P4: Failed to checkout " + file_path + "\n" + error_message
	push_error(full_error)
	
	# Show dialog
	var dialog = AcceptDialog.new()
	dialog.dialog_text = full_error
	dialog.title = "Perforce Checkout Failed"
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

# Tool menu functions
func _checkout_current_file():
	if not perforce_client:
		push_warning("Perforce client not available")
		return
	
	var current_scene = EditorInterface.get_edited_scene_root()
	if current_scene and current_scene.scene_file_path != "":
		perforce_client.checkout_file(current_scene.scene_file_path)
	else:
		push_warning("No scene currently open")

func _show_checked_out_files():
	if not perforce_client:
		push_warning("Perforce client not available")
		return
	
	var files = perforce_client.get_checked_out_files()
	var changelist = perforce_client.get_godot_changelist_number()
	
	print("=== P4 Auto-Checkout Status ===")
	if changelist != "":
		print("Godot changelist: ", changelist)
	else:
		print("No Godot changelist (files go to default)")
	print("Checked out files this session:")
	for file in files:
		print("  ", file)
	print("Total: ", files.size())
	
	# Also refresh the P4 tab if it exists
	if p4_tab_instance:
		p4_tab_instance.refresh()

# Editor signal handlers
func _on_filesystem_changed():
	# Called when filesystem changes occur - good place to catch scene saves
	if not perforce_client:
		return
	
	var current_scene = EditorInterface.get_edited_scene_root()
	if current_scene and current_scene.scene_file_path != "":
		# Check if scene needs to be checked out
		perforce_client.ensure_checked_out(current_scene.scene_file_path)

func _on_scene_changed(scene_root: Node):
	if scene_root and scene_root.scene_file_path != "":
		if perforce_client:
			# Proactively check out the scene when it's opened for editing
			perforce_client.ensure_checked_out(scene_root.scene_file_path)

func _on_resource_saved(resource: Resource):
	if perforce_client and resource.resource_path != "":
		# Ensure resource was checked out before save (backup check)
		if not perforce_client.ensure_checked_out(resource.resource_path):
			push_error("P4: Failed to checkout resource after save: " + resource.resource_path)

func _on_scene_saved(file_path: String):
	if perforce_client and file_path != "":
		# Ensure scene was checked out before save (backup check)
		if not perforce_client.ensure_checked_out(file_path):
			push_error("P4: Failed to checkout scene after save: " + file_path)

func _on_project_run_started():
	if not perforce_client:
		return
	
	# Checkout project.godot and main scene before running
	perforce_client.ensure_checked_out("res://project.godot")
	
	var main_scene = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene != "":
		perforce_client.ensure_checked_out(main_scene)

# Optional: Override to provide custom state
func _get_state():
	var state = {}
	if perforce_client:
		state["checked_out_files"] = perforce_client.checked_out_files
	return state

func _set_state(state):
	if state.has("checked_out_files") and perforce_client:
		perforce_client.checked_out_files = state.checked_out_files
