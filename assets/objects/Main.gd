extends Node

const entry_button_file = preload("res://assets/objects/entry_button.tscn")
const offset_value = 32

onready var L_window = $Left_window/Container
onready var R_window = $Right_window/Container
var opened_dialog = false
var dia_ref #unintiated reference to the popup dialog box that is used when selecting files/folders
var current_folder_path = ""
var soh_folder = ""

func populate_list(entry : String, folder_path : String, container : Node, group_name : String):
	#Populates a given field with entry_button nodes representing a .otr file
	var new_instance = entry_button_file.instance()
	new_instance.add_to_group(group_name)
	new_instance.set_text(entry)
	new_instance.mod_file_path = folder_path + OS_check() + entry
	new_instance.toggle_dir_buttons(false)
	container.add_child(new_instance)

func handle_offset():
	var side_groups = ["R-side", "L-side"]
	for group in side_groups:
		var iter_count = 1
		for nodes in get_tree().get_nodes_in_group(group):
			nodes.rect_position.y = offset_value * iter_count
			iter_count += 1
			nodes.get_parent().rect_min_size.y = offset_value * iter_count

func swap_sides(obj_ref):
	#This is called from the entry_button node via the "Pressed" signal, obj_ref is the sender of the signal
	#This may also be called from the clear load order option to return mods to the folder list if they were pulled from it.
	if obj_ref.is_in_group("L-side"):
		obj_ref.remove_from_group("L-side")
		obj_ref.get_parent().remove_child(obj_ref)
		R_window.add_child(obj_ref)
		obj_ref.add_to_group("R-side")
		obj_ref.toggle_dir_buttons(false)
	elif obj_ref.is_in_group("R-side"):
		obj_ref.remove_from_group("R-side")
		obj_ref.get_parent().remove_child(obj_ref)
		L_window.add_child(obj_ref)
		obj_ref.add_to_group("L-side")
		obj_ref.toggle_dir_buttons(true)
	handle_offset()

func assign_soh_folderpath_text(new_path_text : String):
	$soh_path.bbcode_text = "[center]     Ship of Harknian folder path:\n " + new_path_text + "[/center]"

func save_mod_list():
	#Saves mod list to a .json file
	var stored_data = {}
	var iter_count = 0
	for nodes in get_tree().get_nodes_in_group("L-side"):
		stored_data.merge({iter_count : nodes.mod_file_path})
		iter_count += 1
	if iter_count > 0:
		var file_path = soh_folder + OS_check() + "load-order.json"
		stored_data.merge({"List-size" : str(iter_count - 1)})
		var file = File.new()
		file.open(file_path, file.WRITE)
		file.store_line(to_json(stored_data))
		file.close()
		$msg_label.display_text("load-order.json file saved!")
		opened_dialog = false

func find_soh(path : String) -> bool:
	var soh_file_names = ["\\soh.exe", "/soh.appimage", "/soh.dmg"]
	var file = File.new()
	for names in soh_file_names:
		if file.file_exists(path + names) == true:
			return true
	return false
	
func OS_check() -> String:
	match OS.get_name():
		"Windows", "UWP":
			return("\\")
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return("/")
		"macOS":
			return("/")
	return "/" #If it is not detected it is likely running some form on linux...maybe

func check_if_on_load_list(file_name : String) -> bool:
	#Checks to see if a element is already on the Mod Load Order List, which will then prevent it
	#From loading into the Mod List when another folder is selected.
	for nodes in get_tree().get_nodes_in_group("L-side"):
		if nodes.get_text() == file_name:
			return true
	return false

func on_soh_folder_select(opened_path):
	dia_ref.queue_free()
	opened_dialog = false
	if find_soh(opened_path) == true:
		soh_folder = opened_path
		assign_soh_folderpath_text(soh_folder)
		$Middle_window/VBoxContainer/save_list.disabled = false
		$msg_label.display_text("Found SoH folder!")
	else:
		$msg_label.display_text("Folder selected does not contain SoH.")

func on_mods_folder_select(opened_path):
	#Selects the folder containing .otr files
	dia_ref.queue_free()
	for nodes in get_tree().get_nodes_in_group("R-side"):
		nodes.queue_free()
	yield(get_tree().create_timer(0.5), "timeout")
	opened_dialog = false
	var dir = Directory.new()
	if dir.open(opened_path) == OK:
		current_folder_path = opened_path
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".otr"):
				if check_if_on_load_list(file_name) == false:
					populate_list(file_name, opened_path, R_window, "R-side")
					handle_offset()
			file_name = dir.get_next()

func on_dialog_close():
	#In the event the player closes a dialog box, frees it then allows the player to spawn more.
	dia_ref.queue_free()
	opened_dialog = false

func _on_load_folder_pressed():
	#Folder dialog for selecting a folder
	if opened_dialog == false:
		opened_dialog = true
		var dialog = FileDialog.new()
		dialog.mode = FileDialog.MODE_OPEN_DIR
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.connect("dir_selected", self, "on_mods_folder_select")
		dialog.connect("popup_hide", self, "on_dialog_close")
		self.add_child(dialog)
		dia_ref = dialog
		dialog.popup(Rect2(0, 0, 700, 500))

func _on_save_list_pressed():
	if soh_folder != "":
		if L_window.get_child_count() != 0:
			save_mod_list()
		else:
			$msg_label.display_text("Please populate load order list before saving.")
	else:
		$msg_label.display_text("Please select a SoH folder first.")

func _on_clear_load_list_pressed():
	var found_mods_in_same_folder = false
	for nodes in get_tree().get_nodes_in_group("L-side"):
		if current_folder_path != "":
			if nodes.mod_file_path.begins_with(current_folder_path) == true:
				found_mods_in_same_folder = true
				swap_sides(nodes)
			else:
				nodes.queue_free()
		else:
			nodes.queue_free()
	if found_mods_in_same_folder == true:
		$msg_label.display_text("Found used mods in current folder, returning them...")

func _on_clear_mod_list_pressed():
	for nodes in get_tree().get_nodes_in_group("R-side"):
		current_folder_path = ""
		nodes.queue_free()

func _on_soh_folder_pressed():
	#File dialog for selecting SoH path
	if opened_dialog == false:
		opened_dialog = true
		var dialog = FileDialog.new()
		dialog.mode = FileDialog.MODE_OPEN_DIR
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.connect("dir_selected", self, "on_soh_folder_select")
		dialog.connect("popup_hide", self, "on_dialog_close")
		self.add_child(dialog)
		dia_ref = dialog
		dialog.popup(Rect2(0, 0, 700, 500))
