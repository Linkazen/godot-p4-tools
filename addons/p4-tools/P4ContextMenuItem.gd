
@tool
extends RefCounted
class_name P4ContextMenuItem

enum MENU_ID {
	CHECK_OUT
}

var id: MENU_ID
var name: String
var icon: String
var is_visible: Callable
var is_enabled: Callable
var execute: Callable


func _init(id: MENU_ID, name: String, icon: String, is_visible: Callable, is_enabled: Callable, execute: Callable) -> void:
	self.id = id
	self.name = name
	self.icon = icon
	self.is_visible = is_visible
	self.is_enabled = is_enabled
	self.execute = execute

