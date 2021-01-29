import Pkg
Pkg.update()

Pkg.add("MsgPack")
Pkg.add("Erdos")

Pkg.build("EzXML") # not used directly, needed as a workaround for issues with Erdos
