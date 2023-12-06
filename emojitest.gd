extends Control


var emoji:SpriteFrames
onready var rt: RichTextLabel = $RichTextLabel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	emoji = load("res://emoji.res")
	rt.add_image(emoji.get_frame("emoji",0))
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass
