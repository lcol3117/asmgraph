import Pkg
Pkg.update()

Pkg.add("MsgPack")
Pkg.add("Erdos")

Pkg.build("EzXML") # not used directly, just as a workaround for an issue in Erdos
