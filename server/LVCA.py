import zmq
import time


ip = 'tcp://192.168.1.10'#127.0.0.1 public Ip of server, where this scrip runs
P_PUB = ':6125'#Exposed ports
P_SUB = ':45871'
CHATROOMS = {'g':1,'cg':1,'i':1}
CACHEROOMS = {'cg':[b'cg-']}

_send_buff=[]

context = zmq.Context()

# Socket facing producers
frontend = context.socket(zmq.SUB)
backend = context.socket(zmq.XPUB)

frontend.bind(ip+P_SUB)
backend.bind(ip+P_PUB)

# Subscribe to every single topic from publisher
frontend.setsockopt(zmq.SUBSCRIBE, b"")
backend.setsockopt(zmq.XPUB_VERBOSE, 1)


# We route topic updates from frontend to backend, and
# we handle subscriptions by sending whatever we cached,
# if anything:
poller = zmq.Poller()
poller.register(frontend, zmq.POLLIN)#Listeb users
poller.register(backend, zmq.POLLIN)#Listen new subscription
#poller.register(backend, zmq.POLLOUT)#Listen new subscription


online_users = 0
while True:
    _buffer = bytearray()
    try:
        events = dict(poller.poll(1000))

        # Any new topic data we cache and then forward
        if (frontend in events) and (events[frontend]==zmq.POLLIN):
            msg = frontend.recv()
            backend.send(msg)
            print("Recieve %s bytes"%[len(msg)])
            _cache = CACHEROOMS.get('c'+str(msg[:1],'utf-8'))
            if(_cache is not None):
                _cache.append(b'c'+msg)
                _cache=_cache[-11:]
            
        for c_rooms in CACHEROOMS.values():
            if len(c_rooms):
                backend.send_multipart(c_rooms)


        # When we get a new subscription we pull data from the cache:
        if backend in events:
            if (events[backend] == zmq.POLLIN):
               # print("Subription alert")
                s_msg = backend.recv()
                # Event is one byte 0=unsub or 1=sub, followed by topic
                if s_msg[0] == 1:
                    online_users +=1
                    if CHATROOMS.get(str(s_msg[1:],'utf-8')):
                        #print ('Subscribered to %s: %d'%(s_msg[1:],online_users))
                        pass
                    
                elif s_msg[0] == 0:
                    online_users -=1
                    #print( 'Unsubscribe: %d'%online_users)
    except :
        print("interrupted")
        break
    #time.sleep(1)
    #print(len(CACHEROOMS['cg']))


print("Closing zmq socktes and context")
frontend.close()
backend.close()
context.term()



