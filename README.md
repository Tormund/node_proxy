# node_proxy
Node proxy for rod game engine

Usage:
import rod.node
    import rod.viewport
    import rod.rod_types
    import rod.component
    import rod.component.text_component
    import rod.component / [ sprite, solid, camera ]
    import nimx / [ animation, types, matrixes ]

    proc nodeForTest(): Node =
        result = newNode("test")
        var child1 = result.newChild("child1")

        var a = newAnimation()
        a.loopDuration = 1.0
        a.numberOfLoops = 10
        child1.registerAnimation("animation", a)

        var child2 = result.newChild("child2")

        var child3 = child2.newChild("somenode")
        discard child3.component(Text)

        discard child2.newChild("sprite")

        a = newAnimation()
        a.loopDuration = 1.0
        a.numberOfLoops = 10
        result.registerAnimation("in", a)

    proc getSomeEnabled(): bool = result = true

    nodeProxy TestProxy:
        nilNode Node {add: someNode}:
            alpha = 0.1
            enabled = getSomeEnabled()

        someNode Node {named: "somenode"}:
            parent.enabled = false

        text* Text {comp: "somenode"}:
            text = "some text"

        child Node {named: "child1"}

        text2 Text {compAdd: nilNode}

        source int {ctor: 100500}

        anim Animation {anim: (node: child, key: "animation")}:
            numberOfLoops = 2
            loopDuration = 0.5

        anim2 Animation {anim: "in"}:
            numberOfLoops = 3
            loopDuration = 1.5

    var tproxy = new(TestProxy, nodeForTest())
