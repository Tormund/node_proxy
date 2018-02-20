import rod / [ rod_types, node ]
import rod / utils / serialization_helpers
import nimx / [ animation ]

import tables, algorithm, macros, typetraits

template declProxyType(typ): untyped =
    type typ* = ref object of RootObj

template errorInvalidProxy(node): untyped =
    error node.lineinfo & " Invalid proxy kind " & $node.kind & " | " & repr(node)

template errorInvalidExtension(node): untyped =
    error node.lineinfo & " Invalid proxy extension " & $node.kind & " | " & repr(node)

template warningUnknownExtension(node): untyped =
    warning node.lineinfo & " Unknown property extension: \n" & repr(node)

template publicProperty(nodename, nodetype: string): untyped=
    newIdentDefs(newNimNode(nnkPostfix).add(newIdentNode("*")).add(newIdentNode(nodename)), newIdentNode(nodetype))

# template publicProperty(nodename, nodetype: NimNode): untyped=
#     newIdentDefs(newNimNode(nnkPostfix).add(newIdentNode("*")).add(nodename), nodetype)

proc fixAssign(n: NimNode, field: NimNode): NimNode=
    var asgnNode = n[0]
    var prevAsgn: NimNode
    while asgnNode.kind == nnkDotExpr:
        prevAsgn = asgnNode
        asgnNode = asgnNode[0]

    if prevAsgn.isNil:
        prevAsgn = n

    var asgnExp = newNimNode(nnkDotExpr).add(newIdentNode("np")).add(field)
    var asgnExp2 = newNimNode(nnkDotExpr).add(asgnExp).add(asgnNode)
    prevAsgn[0] = asgnExp2
    result = n

const extPriority = ["ctor", "named", "add"]

proc parseExt(ext: NimNode, property: NimNode, typ: NimNode): tuple[ext: string, res: NimNode] =
    let nodeProxy = newNimNode(nnkDotExpr).add(newIdentNode("np"))
    let target = newNimNode(nnkDotExpr).add(newIdentNode("np")).add(property)
    let rootNode = newNimNode(nnkDotExpr).add(newIdentNode("np")).add(newIdentNode("node"))
    var asgn = newNimNode(nnkAsgn).add(target)

    case ext.kind:
    of nnkExprColonExpr:
        if ext[0].kind == nnkIdent:
            let extName = ext[0]
            result.ext = $extName
            case $extName.ident:
            of "ctor":
                var call = newCall("ctor", ext[1])
                asgn.add(call)
                result.res = asgn

            of "named":
                var call = newCall("named", rootNode, ext[1])
                asgn.add(call)
                result.res = asgn

            of "add":
                var call = newCall("add", nodeProxy.add(ext[1]), newStrLitNode($property.ident))
                asgn.add(call)
                result.res = asgn

            of "comp", "compAdd":
                var call: NimNode
                if ext[1].kind == nnkStrLit:
                    let findCall = newCall("findNode", rootNode, ext[1])
                    call = newCall(ext[0], findCall, typ)
                else:
                    nodeProxy.add(ext[1])
                    call = newCall(ext[0], nodeProxy, typ)
                asgn.add(call)
                result.res = asgn

            of "anim":
                var call: NimNode
                if ext[1].kind == nnkPar:
                    var node: NimNode
                    var key: NimNode
                    for ch in ext[1].children:
                        if ch.kind == nnkExprColonExpr:
                            if ch[0].kind == nnkIdent:
                                if $ch[0].ident == "node":
                                    node = ch[1]
                                elif $ch[0].ident == "key":
                                    key = ch[1]

                    if not node.isNil and not key.isNil:
                        if node.kind == nnkIdent:
                            call = newCall("anim", nodeProxy.add(node), key)
                        elif node.kind == nnkStrLit:
                            let findCall = newCall("findNode", rootNode, node)
                            call = newCall("anim", findCall, key)
                else:
                    call = newCall("anim", rootNode, ext[1])

                asgn.add(call)
                result.res = asgn

            else:
                warningUnknownExtension(ext)
        else:
            errorInvalidExtension(ext)
    of nnkIdent:
        discard
    else:
        errorInvalidExtension(ext)


proc getProperty(cmd: NimNode): tuple[pname, ptype: NimNode]=
    if cmd.kind == nnkCommand:
        if cmd.len == 2 and cmd[0].kind == nnkIdent and cmd[1].kind == nnkIdent:
            result.pname = cmd[0]
            result.ptype = cmd[1]
        elif cmd[0].kind == nnkCommand:
            result.pname = cmd[0][0]
            result.ptype = cmd[0][1]

macro nodeProxy*(head, body: untyped): untyped =
    result = newNimNode(nnkStmtList)

    var typeDesc = getAst(declProxyType(head))
    result.add typeDesc

    var propList = newNimNode(nnkRecList)

    var nodePdesc = publicProperty("node", "Node")
    propList.add(nodePdesc)

    var extensions = initOrderedTable[string, seq[NimNode]]()
    var modifiers = newSeq[NimNode]()

    for cmd in body.children:
        if cmd.kind == nnkCommand:
            var (propName, propTyp) = getProperty(cmd)
            if cmd.len > 1 and not propName.isNil:
                for cmdcont in cmd.children:
                    case cmdcont.kind:
                    of nnkCommand, nnkIdent:
                        # skip property decl
                        # we already have property from getProperty
                        continue

                    of nnkTableConstr, nnkCurly: # property ext
                        for ext in cmdcont.children:

                            let genExt = parseExt(ext, propName, propTyp)
                            if not genExt.res.isNil:
                                var extSeq = extensions.getOrDefault(genExt.ext)
                                if extSeq.isNil:
                                    extSeq = @[]
                                extSeq.add(genExt.res)
                                extensions[genExt.ext] = extSeq

                    of nnkStmtList: # property modifiers
                        for ch in cmdcont:
                            modifiers.add(fixAssign(ch, propName))
                    else:
                        errorInvalidProxy(cmdcont)

            if not propName.isNil:
                if $propName.ident == "node":
                    error propName.lineinfo & " property named `node` reserved "
                let pdesc = newIdentDefs(propName, propTyp)
                propList.add(pdesc)
        else:
            errorInvalidProxy(cmd)

    typeDesc[0][2][0][2] = propList

    result.add(newNimNode(nnkEmpty))
    extensions.sort do(a,b: (string, seq[NimNode])) ->int:
        var ia = extPriority.find(a[0])
        var ib = extPriority.find(b[0])
        ia = if ia < 0: 100 else: ia
        ib = if ib < 0: 100 else: ib
        cmp(ia, ib)

    block ctorGen:
        let procName = newNimNode(nnkPostfix).add(newIdentNode("*")).add(newIdentNode("new"))
        let ddd = newIdentDefs(newIdentNode("typ"), newNimNode(nnkBracketExpr).add(newIdentNode("typedesc")).add(head))
        var procArg = newIdentDefs(newIdentNode("inode"), newIdentNode("Node"))
        var ctorDef = newProc(
            procName,
            [head, ddd, procArg]
        )

        let nodeProxy = newIdentNode("np")

        var ct = quote do:
            let `nodeProxy` = new(`head`)
            `nodeProxy`.node = inode

        ctorDef.body.add(ct)

        for k, ext in extensions:
            ctorDef.body.add(ext)

        for nmod in modifiers:
            ctorDef.body.add(nmod)

        ctorDef.body.add(nodeProxy)
        result.add(ctorDef)

    when defined(debugNodeProxy):
        echo "\ngen finished \n ", repr(result)

#[
    Extensions
]#

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

when isMainModule:
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

        var child4 = child2.newChild("sprite")

        a = newAnimation()
        a.loopDuration = 1.0
        a.numberOfLoops = 10
        result.registerAnimation("in", a)

    proc getSomeEnabled(): bool = result = true

    nodeProxy TestProxy:
        myNode2 Node {ctor: nodeForTest()}
        nilNode Node {add: someNode}:
            alpha = 0.1
            enabled = getSomeEnabled()

        someNode Node {named: "somenode"}:
            parent.enabled = false

        text Text {comp: "somenode"}:
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
    echo "node name ", tproxy.node.name, " Text comp text ", tproxy.text.text, " intval ", tproxy.source
