extends LineEdit

signal text_updated(update_text)

var counter:int = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.




func _on_LineEdit_text_changed(new_text: String) -> void:
	
	if counter < new_text.length():
		var updated_text:String = text.substr(counter)
		print("New text enetered: %s"%updated_text)
		print("w_char: %s utf8: %s"%[updated_text.to_wchar().hex_encode(),
		updated_text.to_wchar()])
#		if int(updated_text.to_utf8()[0])> 255:
		#emit_signal("text_updated",updated_text)
	
	counter = len(new_text)
	


func _on_LineEdit_text_entered(new_text: String) -> void:
	counter =0


func _on_LineEdit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		print(event.unicode)
		emit_signal("text_updated",str(event.unicode))

	
