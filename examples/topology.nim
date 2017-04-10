import nimoy, future

type  
  ActorNode[In, Out] =
    proc(self: ActorRef[In], subscriber: ActorRef[Out])
  
  Topology = object
    system: ActorSystem
    
#   Edge[In,X,Out] = tuple
#     left: ActorNode[In,X]
#     right: ActorNode[X,Out]  

# proc `~>`[A,X,B](left: ActorNode[A,X], right: ActorNode[X,B]): Edge[A,X,B] =
#   (left, right)

proc createTopology(system: ActorSystem): Topology =
  Topology(system: system)

proc createTopology(): Topology =
  Topology(system: createActorSystem())


proc initNode[In,Out](
  topology: Topology, 
  actorNode: ActorNode[In, Out], 
  subscriber: ActorRef[Out]
): ActorRef[In] =
  topology.system.initActor(
    (self: ActorRef[In]) => 
      actorNode(self, subscriber))

proc broadcastRef[In](
  topology: Topology, 
  subscribers: varargs[ActorRef[In]]): ActorRef[In] =
  let subs = @subscribers
  topology.system.createActor do (self: ActorRef[In], m: In): 
      for s in subs:
        s ! m

proc node[In,Out]( f: proc(x:In): Out ): ActorNode[In,Out] = 
  (self: ActorRef[In], subscriber: ActorRef[Out]) => 
    self.become((inp: In) => subscriber.send(f(inp)))

proc sinkNode[In]( f: proc(x:In) ): ActorInit[In] =
  (self: ActorRef[In]) =>
    self.become((inp: In) => f(inp))

proc broadcastNode[In](node1: ActorRef[In], node2: ActorRef[In]): ActorInit[In] =
  (self: ActorRef[In]) => 
    self.become do (inp: In):
      node1.send(inp)
      node2.send(inp)

proc sinkRef[In](topology: Topology, f: proc(x:In) ): ActorRef[In] =
   topology.system.initActor(sinkNode(f))

proc nodeRef[In,Out](topology: Topology, f: proc(x:In): Out, subscriber: ActorRef[Out]): ActorRef[In] =
   topology.initNode(node[In,Out](f), subscriber)



#
# source ~> map1 ~> fanIn ~> map3 ~> broadcast ~> sink1
#    +~~~~> map2 ~~~~~^                 +~~~~> sink2
#  


let t = createTopology()

let sink1Ref = t.sinkRef((x: int) => echo("sink1 = ", x))
let sink2Ref = t.sinkRef((x: int) => echo("sink2 = ", x))
let bref     = t.broadcastRef(sink1Ref, sink2Ref)
let map3Ref  = t.nodeRef((x: int) => x+7,  bref)
let fanInRef = t.nodeRef((x: int) => ( echo("fan in = ", x); x ), map3Ref)
let map2Ref  = t.nodeRef((x: int) => x-1, fanInRef)
let map1Ref  = t.nodeRef((x: int) => x*2, fanInRef)

# send input
for i in 0..10:
  map1Ref ! i

t.system.awaitTermination()

