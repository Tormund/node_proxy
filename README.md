# node_proxy
macro for wrapping Node's and their children with components
for rod game engine

Node proxy for rod game engine

#Usage:

Create test node tree with components and animation

```
    proc nodeForTest(): Node =
        result = newNode("test")
        var child1 = result.newChild("child1")
        var child2 = result.newChild("child2")
        var child3 = child2.newChild("somenode")
        discard child3.component(Text)
        discard child2.newChild("sprite")

        var a = newAnimation()
        a.loopDuration = 1.0
        a.numberOfLoops = 10
        child1.registerAnimation("animation", a)

        a = newAnimation()
        a.loopDuration = 1.0
        a.numberOfLoops = 10
        result.registerAnimation("in", a)

    proc getSomeEnabled(): bool = result = true
```

 Define node proxy
 node proxy allways has property - ```node* : Node``` - this is root node of proxy

```
nodeProxy TestProxy:
    # crate node and add to someNode
    nilNode Node {add: someNode}:
        # we can modify Node's properties directly here
        alpha = 0.1
        enabled = getSomeEnabled()

    # findNode named "somenode"
    someNode Node {named: "somenode"}:

        parent.enabled = false

    # get component from node named "somenode"
    text* Text {comp: "somenode"}:
        text = "some text"

    child Node {named: "child1"}

    text2 Text {compAdd: nilNode}

    # ctor is contructor
    source int {ctor: 100500}

    # get animation from node `child` with animation key "animation"
    anim Animation {anim: (node: child, key: "animation")}:
        numberOfLoops = 2
        loopDuration = 0.5

    # get animation from root node with key "in"
    anim2 Animation {anim: "in"}:
        numberOfLoops = 3
        loopDuration = 1.5
```

# Macro output

```
type
  TestProxy* = ref object of RootObj
    node*: Node
    nilNode: Node
    someNode: Node
    text*: Text
    child: Node
    text2: Text
    source: int
    anim: Animation
    anim2: Animation

proc new*(typ: typedesc[TestProxy]; inode: Node): TestProxy =
  let np = new(TestProxy)
  np.node = inode
  np.source = ctor(100500)
  np.someNode = named(np.node, "somenode")
  np.child = named(np.node, "child1")
  np.nilNode = add(np.someNode, "nilNode")
  np.text = comp(findNode(np.node, "somenode"), Text)
  np.text2 = compAdd(np.nilNode, Text)
  np.anim = anim(np.child, "animation")
  np.anim2 = anim(np.node, "in")
  np.nilNode.alpha = 0.1
  np.nilNode.enabled = getSomeEnabled()
  np.someNode.parent.enabled = false
  np.text.text = "some text"
  np.anim.numberOfLoops = 2
  np.anim.loopDuration = 0.5
  np.anim2.numberOfLoops = 3
  np.anim2.loopDuration = 1.5
  np

```

# Create proxy
var tproxy = new(TestProxy, nodeForTest())
echo "proxy ", tproxy.node.name
