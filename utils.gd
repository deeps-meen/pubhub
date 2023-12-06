extends Reference

class_name File_Utils
const MAX_SIZE = 65535
const IMAGE_CHAT = 'i'

signal finished

var id:int
var name:String
var size:int
var _buffer:PoolByteArray
var _metadata:PoolByteArray
var _sent:int =0#Number of packets sent
var _flag:int=1
var offset:int=0
var _time_ms:int

func get_img(file_path)->void:
	if !file_path:
		return
	var text
	var img:Image
	
	if file_path is String:
		text = load(file_path)
		if text==null:
			img = Image.new()
			img.load(file_path)
	elif file_path is ImageTexture:
		text = file_path
	img = text.get_data() if text else img
	#compress(img)
	_metadata = ("%d:%d:%d:%d"%[img.get_width(),img.get_height(),int(img.has_mipmaps()),img.get_format()]).to_utf8()
	#,img.get_data()]
	_buffer = img.get_data()
	size = _buffer.size()
	print_debug("Send [%d] bytes"%size)

func compress(img:Image)->void:
	var osize = img.get_data().size()
	img.resize(1080,1920,Image.INTERPOLATE_TRILINEAR)
	print("Compress factor %0.2f%%"%((img.get_data().size()/float(osize))*100.0))

func set_img()->ImageTexture:
	print("Recv [%d] bytes"%_sent)
	var text:ImageTexture = ImageTexture.new()
	var img:Image = Image.new()
	img.callv("create_from_data",_get_metadata())
	text.create_from_image(img)
	return text

func _get_metadata()->Array:
	var m = _metadata.get_string_from_utf8().split(':')
	return [int(m[0]),int(m[1]),bool(int(m[2])),int(m[3]),_buffer]

func get_data()->PoolByteArray:
	var pkt:PoolByteArray = (IMAGE_CHAT+str(offset-1)+str(id)).to_utf8()
	_set_flag()
	if _sent==0:
		#First packet metadata
		_time_ms = Time.get_ticks_msec()
		pkt.append_array(("%s:%s:%d:"%[id,name,size]).to_utf8())
		pkt.append_array(_metadata)
		_sent+=1
	elif (size -_sent+1) > MAX_SIZE-offset-1:
		pkt.append_array(_buffer.subarray(_sent-1,_sent-2-offset+MAX_SIZE))
		_sent+= (MAX_SIZE -offset)
	else:
		pkt.append_array(_buffer.subarray(_sent-1,size-1))
		_sent =-1
		print("Time taken: [%s] seconds"%(Time.get_ticks_msec()-_time_ms))
		emit_signal("finished")
	
	return pkt

#_sent number of packets recieved
func recv_data(pkt:PoolByteArray)->bool:
	if pkt and pkt.size() >0 and char(pkt[0])==IMAGE_CHAT:
		var _ofset:int = int(char(pkt[1]))
		var _id:String = pkt.subarray(2,1+_ofset).get_string_from_utf8()
		pkt = pkt.subarray(2+_ofset,-1)
		if _sent ==0:
			id = int(_id)
			offset = _ofset
			var _data=pkt.get_string_from_utf8().split(':')
			assert(_id == _data[0],"Image corrupted")
			name=_data[1]
			size = int(_data[2])
			_metadata= ("%s:%s:%s:%s"%[_data[3],_data[4],_data[5],_data[6]]).to_utf8()
			_sent+=1
		elif _id == str(id):
			_buffer.append_array(pkt)
			_sent += pkt.size()
		
		if (_sent-1)>=size:
			_buffer.resize(size)
			emit_signal("finished")
			return true
	return false

func get_flag()->int:
	return _flag

func _set_flag()->void:
	if _sent == 0:
		_flag= 1
	elif (size - _sent+1) > MAX_SIZE -offset-1:
		_flag= 2
	_flag= 1

func has_data()->bool:
	return (_sent!=-1) and (size>0)



func _init(file_name:String,src) -> void:
	id = randi()%10000
	offset=len(str(id))+1
	name = file_name.substr(0,20)
	get_img(src)
	
