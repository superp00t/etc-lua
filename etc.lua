function rev(t)
    local reversedTable = {}
    local itemCount = #t
    for k, v in ipairs(t) do
        reversedTable[itemCount + 1 - k] = v
    end
    return reversedTable
end

Buffer = {}
Buffer.__index = Buffer

function Buffer:new(array)
   local buff = {}  
   setmetatable(buff, Buffer)
   if array == nil then
      buff.data = {}
   else
    if type(array) == string then
        for i = 1, #array do
            buff.data[i] = string.byte(array, i)
        end
    else
        buff.data = array
    end
   end
   buff.wpos = #buff.data + 1
   buff.rpos = 1
   return buff
end

function Buffer:readByte()
   ch = self.data[self.rpos]
   self.rpos = self.rpos + 1
   return ch
end

function Buffer:readBytes(i)
    out = {}
    for x = 1, i do
        table.insert(out, self:readByte())
    end
    return out
end

function Buffer:writeBytes(v)
    for x = 1, (#v+1) do
    	print("writing byte", x)
        self:writeByte(v[x])
    end
end

function Buffer:writeByte(ch)
	if self.wpos == #self.data then
	  table.insert(self.data, ch)
	else
	  self.data[self.wpos] = ch
	end
    self.wpos = self.wpos + 1
    print("wrote byte ", self.data[self.wpos - 1])
end

function Buffer:writeUint(x)
	c = x
	while c > 127 do
		print(c)
		self:writeByte(bit.band(bit.bor(c, 0x80), 0xFF))
		c = bit.brshift(c, 7)
	end

 	self:writeByte(bit.band(c, 0xFF))
end

function Buffer:readUint()
	b = self:readByte()
	if b < 128 then
		return b
	end
	
	value = bit.band(bit.band(b, 0xFF), 0x7F)
	
	shift = 7
	
	while b >= 128 do
		b = self:readByte()
		value = bit.bor(value, bit.blshift(bit.band(bit.band(b, 0xFF), 0x7F), shift))
		shift = shift + 7
	end
	
	return value
end

function Buffer:readDouble()
    bytes = rev(self:readBytes(8))
    local sign = 1
    local mantissa = bytes[2] % 2^4
    for i = 3, 8 do
      mantissa = mantissa * 256 + bytes[i]
    end
    if bytes[1] > 127 then sign = -1 end
    local exponent = (bytes[1] % 128) * 2^4 + math.floor(bytes[2] / 2^4)
 
    if exponent == 0 then
      return 0
    end
    mantissa = (math.ldexp(mantissa, -52) + 1) * sign
    return math.ldexp(mantissa, exponent - 1023)
end

function Buffer:writeDouble(num)
   local bytes = {0,0,0,0, 0,0,0,0}
   if num == 0 then
     return bytes
   end
   local anum = math.abs(num)

   local mantissa, exponent = math.frexp(anum)
   exponent = exponent - 1
   mantissa = mantissa * 2 - 1
   local sign = num ~= anum and 128 or 0
   exponent = exponent + 1023

   bytes[1] = sign + math.floor(exponent / 2^4)
   mantissa = mantissa * 2^4
   local currentmantissa = math.floor(mantissa)
   mantissa = mantissa - currentmantissa
   bytes[2] = (exponent % 2^4) * 2^4 + currentmantissa
   for i = 3, 8 do
     mantissa = mantissa * 2^8
     currentmantissa = math.floor(mantissa)
     mantissa = mantissa - currentmantissa
     bytes[i] = currentmantissa
   end
   self:writeBytes(rev(bytes))
end

-- Does not quite work right. Produces mildly inaccurate floats. Use float64 for now.
function Buffer:readFloat()
    local xStream = rev(self:readBytes(4))
    local x = ""
    for i = 1, 4 do
      x = x .. string.char(xStream[i])
    end
    local n = 4
    local sign = 1
    local mantissa = string.byte(x, (opt == 'd') and 7 or 3) % ((opt == 'd') and 16 or 128)
    for i = n - 2, 1, -1 do
      mantissa = mantissa * (2 ^ 8) + string.byte(x, i)
    end

    if string.byte(x, n) > 127 then
      sign = -1
    end

    local exponent = (string.byte(x, n) % 128) * ((opt == 'd') and 16 or 2) + math.floor(string.byte(x, n - 1) / ((opt == 'd') and 16 or 128))
    if exponent == 0 then
      return 0.0
    else
      mantissa = (math.ldexp(mantissa, (opt == 'd') and -52 or -23) + 1) * sign
      return math.ldexp(mantissa, exponent - ((opt == 'd') and 1023 or 127))
    end
end

function fch(c)
    return bit.band(c, 0xFF)
end

function Buffer:writeFloat(n)
    local bytes = {}
    local val = n
    local sign = 0

    if val < 0 then
      sign = 1
      val = -val
    end

    local mantissa, exponent = math.frexp(val)
    if val == 0 then
      mantissa = 0
      exponent = 0
    else
      mantissa = (mantissa * 2 - 1) * math.ldexp(0.5, (opt == 'd') and 53 or 24)
      exponent = exponent + ((opt == 'd') and 1022 or 126)
    end

    local bytes = {}

    table.insert(bytes, fch(math.floor(mantissa) % (2 ^ 8)))
    val = math.floor(mantissa / (2 ^ 8))
    table.insert(bytes, fch(math.floor(val) % (2 ^ 8)))
    val = math.floor(val / (2 ^ 8))

    table.insert(bytes, fch(math.floor(exponent * ((opt == 'd') and 16 or 128) + val) % (2 ^ 8)))
    val = math.floor((exponent * ((opt == 'd') and 16 or 128) + val) / (2 ^ 8))
    table.insert(bytes, fch(math.floor(sign * 128 + val) % (2 ^ 8)))
    val = math.floor((sign * 128 + val) / (2 ^ 8))

    self:writeBytes(rev(bytes))
end

function Buffer:readBinaryString(x)
  s = ""
  for i = 1, (x) do
    print(i)
    s = s .. string.char(self:readByte())
  end

  return s
end

function Buffer:writeBinaryString(x)
  for i = 1, #x do
    self:writeByte(string.byte(x, i))
  end
end

function Buffer:readString()
  i = self:readUint()
  str = self:readBinaryString(i)
  return str
end

function Buffer:writeString(v)
  self:writeUint(#v)
  self:writeBinaryString(v)
end
