

class LuaGen(CodeGenerator):
    
    def startFunc(self):
        print self.ws + "function Mips:doop(op)"
        print self.ws + "    local v"
    
    def endFunc(self):
        print self.ws + "    error(string.format(\"unhandled opcode at %x -> %x\",self.pc,op))"
        print self.ws + "end"
    
    def startSwitch(self,switch):
        print self.ws + "v = band(op,%s)" % hex(int(switch,2))
        
    def genCase(self,name,value):
        self.depth -= 1
        print self.ws + "if v == %s then"%hex(value)
        print self.ws + "    return self:op_%s(op)"%name
        print self.ws + "end"
        self.depth += 1
        
    def endSwitch(self):
        pass
