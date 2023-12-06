extends Control

const TEMPLATE = "[color=yellow]@{name}:[/color]{msg}\n"
const SEND_TEMPLATE = "%s:%s"
const GLOBAL_CHAT = 'g'
const CACHE_CHAT = 'c'
const IMAGE_CHAT = 'i'
const VOICE_CHAT = 'v'
const POLL_TIMEOUT_MS = 1
const DELIM = ':'#msg name separator


export(String) var S_ADDR:String = "192.168.1.10"#65.0.138.140
export(String) var PORT_SUB:String = "9999"
export(String) var PORT_PUB:String = "8888"
#export(String) var PORT_PULL:String= "5557"

onready var line_edit: LineEdit = $"%LineEdit"
onready var _b: Button = $"%Button"
onready var text_edit: TextEdit = $"%TextEdit"
onready var inbox: RichTextLabel = $"%inbox"


var _zmq:gzmq
var _send:bool = false
var _send_txt:Array = []
var _name:String = "me"
var _ID_TAG = OS.get_model_name()+str(randi()%100000)
var SOCKETS:= {}
var _is_cache_done = false

var _send_counter:int = 0
var _queue:Array = []
var r_queue:Dictionary = {}

func _ready() -> void:
	
	#Support file dropping
	get_tree().connect("files_dropped",self,"_on_selector_file_selected")
	
	var _rb:Button = $"%record"
	_rb.pressed = false
	#Attach record button signal to IO singleton
	#(bool,Button::Node,AudioStreamPlayer:Node)
	_rb.connect("toggled",IO,"_on_record_toggled",[_rb,$"%AudioStreamRecord"],CONNECT_DEFERRED)
	
	var _fd:FileDialog = $"%selector"
	_fd.current_path ="C:\\Users\\riswi\\Pictures"
	_fd.current_dir = "C:\\Users\\riswi\\Pictures"

	set_process(false)
	var _is_ready:bool = false
	text_edit.hide()
	_name = OS.get_name()
	_zmq = gzmq.new()
	
	_zmq.connect("ctx_closed",self,"ctx_closed")
	#Creates context only once.
	_zmq.zmq_ctx_new() 

	#create socket for Sending message @:SUB_PORT
	SOCKETS["PUB"]=_zmq.is_socket()
	_zmq.zmq_socket(gzmq.PUB,false)#false to set POLLOUT
	#create socket for recieving messages @:PUB_PORT
	#true to set sockopt for SUBSCRIBER
	SOCKETS["SUB"]=_zmq.is_socket()
	_zmq.zmq_socket(gzmq.SUB,true)#true to POLLIN
	
	_zmq.setsockopt(SOCKETS.SUB,gzmq.SUBSCRIBE,GLOBAL_CHAT)
	_zmq.setsockopt(SOCKETS.SUB,gzmq.SUBSCRIBE,CACHE_CHAT+GLOBAL_CHAT)
	_zmq.setsockopt(SOCKETS.SUB,gzmq.SUBSCRIBE,IMAGE_CHAT)
	
	_send_txt.fill("")
	_zmq.connect("msg_recv",self,"_on_msg_recv")
	#Socket count more than one
	if _zmq.is_socket() == 2:
		#Connect SUB
		_is_ready = _zmq.zmq_connect(SOCKETS.SUB,"tcp://%s:%s"%[S_ADDR,PORT_SUB])
		#Connect PUB
		_is_ready = _zmq.zmq_connect(SOCKETS.PUB,"tcp://%s:%s"%[S_ADDR,PORT_PUB])
	
	if !_is_ready:
		_b.disabled = !_is_ready
		line_edit.editable = _is_ready
		line_edit.placeholder_text = "Disconnected :("
		text_edit.show()
		text_edit.text = "Something went wrong."
		set_process(false)
		return
	call_deferred("set_process",true)
	

	
func _process(delta: float) -> void:
	if _zmq.is_socket() and _zmq.is_ctx():
#		print("SendBytes: %s"%_zmq.zmq_send(0,"hello",1))
		var raw_msg = _zmq.zmq_poll(_send_txt,POLL_TIMEOUT_MS)
		if _send:
			_send=false
			_send_txt.clear()
		if _queue and !_queue.empty():
			var f = _queue[0]
			if (f is File_Utils) and f.has_data():
				_zmq.zmq_send(SOCKETS.PUB,f.get_data(),f.get_flag())#SNDMORE=2;Added in next update
			else:
				_queue.pop_front()


func send_img(fname,src)->File_Utils:
	var ref = File_Utils.new(fname,src)
	yield(get_tree(),"idle_frame")
	if ref.has_data():
		line_edit.text = "Sending image %s"%ref.name
		send()
		_queue.append(ref)
		_disable_input(true)
		ref.connect("finished",self,"_disable_input",[false])
	return ref


func send()->void:
	var msg_enter = line_edit.text
	if (_send == false) and msg_enter:
		_send= true
		inbox.show()
		line_edit.set_deferred("text","")
		text_edit.set_deferred("text","")
		add_msg("me",msg_enter)
		var _pd:PoolByteArray =(GLOBAL_CHAT+SEND_TEMPLATE%[_ID_TAG,msg_enter]).to_utf8()
		
		_send_txt.append(_pd)
		_send_counter+=1
	

func add_msg(name_tag:String,msg_txt:String)->void:
	inbox.append_bbcode(TEMPLATE.format({name=name_tag,msg=msg_txt}))
	
func _on_msg_recv(msg)->void:
	if !msg:
		return
	var room:String = char(msg[0])
	if (room is String):
		if (room==CACHE_CHAT):
			#Cache messages
			_zmq.setsockopt(SOCKETS.SUB,gzmq.UNSUBSCRIBE,CACHE_CHAT+GLOBAL_CHAT)
			room = char(msg[1])
			msg = msg.subarray(1,-1)#remove the first byte
			
		if room==GLOBAL_CHAT:
			recv_msg(msg.subarray(1,-1).get_string_from_utf8())
		
		elif room == IMAGE_CHAT:
			var offset = int(char(msg[1]))
			var id:String = msg.subarray(2,1+offset).get_string_from_utf8()
			var f:File_Utils
			if r_queue.has(id):
				f = r_queue[id]
				if !(f is File_Utils):
					r_queue.erase(id)
					push_warning("Corruptp send queue!")
					return
			else:
				f = File_Utils.new("","")
				r_queue[id] = f
			if f.recv_data(msg):
				recv_img(f.set_img())
				r_queue.erase(str(f.id))

	else:
		print("Null message recieved.")

#Create msg and add to inbox display.
#Message should be formated as sender$msg_string
func recv_msg(msg_str:String)->void:
	if !msg_str or msg_str.length() < 4:
		return
	var name_tag:= "[color=red]Spam[/color]"
	var msg:String = str(msg_str)
	var msg_tag = msg_str.split(DELIM,false,1)
	if msg_tag.size() > 1:
		name_tag = msg_tag[0]
		msg = msg_tag[1]
		if (name_tag == _ID_TAG):
			if _send_counter > 0:
				_send_counter-=1 
				inbox.append_bbcode("[b]\tDelievered\n[/b]")
				return
	add_msg(name_tag,msg)

func recv_img(text:ImageTexture)->void:
	var sz:Vector2= get_viewport_rect().size
	inbox.call_deferred("add_image",text,sz.x,sz.y,2)


#@Deprecated
func _on_LineEdit_text_changed(new_text: String) -> void:
	text_edit.set_deferred("text","PREVIEW:\n"+ new_text.to_utf8().hex_encode())
	
	if inbox.visible:
		inbox.hide()
	


func _on_LineEdit_text_entered(new_text: String) -> void:
	send()


func _on_Button_button_down() -> void:
	send()



func _on_inbox_visibility_changed() -> void:
	text_edit.visible = !inbox.visible

func ctx_closed():
	push_warning("Ctx is now closed")


func _on_TextEdit_text_changed() -> void:
	line_edit.text = text_edit.text.lstrip("PREVIEW:\n")



func _on_attachment_button_up() -> void:
	#OS.request_permissions()
	if has_node("/root/IO"):
		IO.call_deferred("load_img")
		var dict = yield(IO,"finish")
		_disable_input(true)
			# Load all images
		if dict.has("0"):
			var image = Image.new()
			# Use load format depending what you have set in plugin setOption()
			var error = image.load_jpg_from_buffer(dict["0"])
			#var error = image.load_png_from_buffer(img_buffer)
			yield(get_tree(),"idle_frame")
			yield(get_tree(),"idle_frame")
			yield(get_tree(),"idle_frame")
			yield(get_tree(),"idle_frame")
			if error != OK:
				print("Error loading png/jpg buffer, ", error)
				_disable_input(false)
				return
			else:
				print("We are now loading texture... ")
				var text = ImageTexture.new()
				text.create_from_image(image,image.get_format())
	#			$"%img".texture = text
				send_img(dict.name,text)
	else:
		$"%selector".popup_centered_ratio(1.0)

func _disable_input(flag:bool)->void:
	$"%attachment".disabled = flag



#Called by windows file explorer
func _on_selector_file_selected(path,_screen=null) -> void:
	
	print(path)
	if $"%attachment".disabled:
		print("Cusy sending file..")
		return
	if path is PoolStringArray:
		path = path[0]
	if path is String:
		var ext:String = path.get_extension()
		if (ext.nocasecmp_to("jpg")==0) or (ext.nocasecmp_to("jpeg")==0) or (ext.nocasecmp_to("png")==0):
			var f_name:String = (path as String).get_file()
			_disable_input(true)
			send_img(f_name,path.replace("\\","/"))



func _on_LineEdit_text_updated(update_text:String) -> void:
	text_edit.set_deferred("text","PREVIEW:\n"+ update_text)
	
	if inbox.visible:
		inbox.hide()

#Turn on the speaker
func _on_voiceplay_toggled(button_pressed: bool) -> void:
	var speaker := $"%AudioReciever"
	if button_pressed:
		speaker.play()
	else:
		speaker.stop()
