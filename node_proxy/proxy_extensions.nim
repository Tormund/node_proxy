import rod / [ rod_types, node ]
import nimx / [ animation ]

export node, animation, rod_types

type NodeProxy* = ref object of RootObj
    node*: Node

method init*(np: NodeProxy, node: Node) {.base.} =
    np.node = node

proc new*(T: typedesc[NodeProxy], node: Node): T =
    result.new()
    result.init(node)

proc ctor*[T](nodector: T): T =
    result = nodector

proc named*(node: Node, name: string): Node = node.findNode(name)
proc add*(node: Node, name: string): Node = node.newChild(name)

proc comp*(node: Node, T: typedesc[Component]): T =
    result = node.getComponent(T)
    assert(not result.isNil, "Component nil")

proc compAdd*(node: Node, T: typedesc[Component]): T =
    assert(node.getComponent(T).isNil, "Component already added")
    result = node.component(T)

proc anim*(node: Node, key: string): Animation =
    result = node.animationNamed(key)
