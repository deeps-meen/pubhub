extends TextureRect


# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var ref:File_Utils = File_Utils.new("testfile.png","C:\\Users\\riswi\\Pictures\\IMG_1021_edit.png")
	texture = ref.set_img()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass
