extends Node


var _plugin_getimg

const _bus_name = "Record"

signal finish(ImageTexture)

#Audio variables
var _effect:AudioEffectRecord = null
var _recording:AudioStreamSample = null

var _vq = PoolByteArray()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	set_process(false)
	#Initialize audio
	
	_effect =AudioServer.get_bus_effect(AudioServer.get_bus_index(_bus_name),0)
	
	match OS.get_name():
		"Android":
			print(OS.get_granted_permissions())
			OS.request_permission("RECORD_AUDIO")
			_plugin_getimg = Engine.get_singleton("GodotGetImage")
			if _plugin_getimg:
				push_warning("Plugin loaded success.")
				_plugin_getimg.connect("image_request_completed",self,"_on_img_load")
				_plugin_getimg.connect("permission_not_granted_by_user",self,"_on_permiisions_fail")
				_plugin_getimg.connect("error",self,"_on_failed")
				return
		_:
			pass
			#call_deferred("queue_free")

func _process(delta: float) -> void:
	if _recording:
		var data = _recording.get_data()
		print(data.size())

func load_img(opt=null)->void:
	if !(_plugin_getimg is FileDialog):
		if !opt:
			opt =  {
		"image_height" : 1920,
		"image_width" : 1080,
		"keep_aspect" : true,
		"auto_rotate_image" : true,
		"image_quality": 90
	}
		_plugin_getimg.setOptions(opt)
		_plugin_getimg.call_deferred("getGalleryImage")
	else:
		_plugin_getimg.popup()

func load_imgs()->void:
	_plugin_getimg.getGalleryImages()

func camshot()->void:
	_plugin_getimg.getCameraImage()


func _on_img_load(dict)->void:
	print("Load done")
	if !dict:
		return
	dict["name"]=str(randi()%1000000)+".jpg"
	# Purge old images
	emit_signal("finish",dict)


func _on_permiisions_fail(permisons):
	print("Allow me to get images %s"%permisons)
	_plugin_getimg.resendPermission()

func _on_failed(e)->void:
	print("Something went wrong %s"%e)

#Listens to record button events
func _on_record_toggled(t:bool,butt:Button,ap:AudioStreamPlayer)->void:

	#Start recording behaviour
	if t:
		_effect.set_recording_active(t)
		
		if _effect.is_recording_active():
			ap.play()
			yield(get_tree(),"idle_frame")
			_recording = _effect.get_recording()
			if _recording:
				print(_recording)
				print(_recording.format)
				print(_recording.mix_rate)
				print(_recording.stereo)
				var data = _recording.get_data()
				print(data.size())
			else:
				butt.disabled = true
				ap.stop()
		else:
			push_warning("Recording not active.")
	else:
		ap.stop()
		_effect.set_recording_active(false)
		_recording = null
