--[==[ bit32 -- compatibility library for Lua 5.4

	Licensed under the MIT License
	Copyright (c) 2021 Andras Horvath

	The MIT License (MIT)
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.


	This library aims to exactly imitate the bit32 standard library of Lua 5.2
	for newer Lua versions in pure Lua code.
	
	For most situations, it seems to be a bad idea to use this module instead of
	changing code to use the 64-bit bitwise operators of Lua 5.4.

	The module tries to follow the Lua Reference Manual, accessible online at
	http://www.lua.org/manual/5.2/manual.html#6.7

	Particular care was taken to coerce inputs and return values to 32-bit wide integers.
	
	As the 5.4 Manual states:
	> Unless otherwise stated, all functions accept numeric arguments in the
	> range (-2^51,+2^51); each argument is normalized to the remainder of
	> its division by 2^32 and truncated to an integer (in some unspecified
	> way), so that its final value falls in the range [0,2^32 - 1].
	> Similarly, all results are in the range [0,2^32 - 1]. Note that
	> bit32.bnot(0) is 0xFFFFFFFF, which is different from -1.

]==]

---- Local helpers

local MAX_32 = 0xFFFFFFFF
-- local MAX_32<const> = 0xFFFFFFFF -- <const> is a syntax error in Lua 5.3


local function toint(x)
	return tonumber(x) // 1 | 0
end


local function to32 (x)
	return toint(x % (2^32))
end


local function low_mask(width)
	return MAX_32 >> (32 - width)
end


local function foldl(f, init, fst, ...)
	if (fst == nil) then 
		return init
	end
	return foldl(f, f(init, fst), ...)
end


local function check_field_width(field, width)
	if field < 0 or field > 31 then
		error("'field' argument out of range [0,31]", 2)
	end
	if width < 0 or width > 31 then
		error("'width' argument out of range [0,31]", 2)
	end
end


---- Module definition

local bit32 ={}

function bit32.arshift(x, disp)
	x = to32(x)
	disp = toint(disp)
	local sign = (x & (1 << 31)) >> 31
	if sign == 0 then
		return to32(x >> disp)
	elseif disp <= 0 then
		return to32(x >> disp)
	elseif disp > 31 then
		return MAX_32
	else
		local fill = to32(MAX_32 << (32 - disp))
		return to32((x >> disp) | fill)
	end
end


function bit32.band(...)
	return foldl(function(x,y) return	x & to32(y) end, MAX_32, ...)
end


function bit32.bnot(x)
	return to32(~to32(x))
end


function bit32.bor(...)
	return foldl(function(x,y) return x | to32(y) end, 0, ...)
end


function bit32.btest(...)
	return bit32.band(...) ~= 0
end


function bit32.bxor(...)
	return foldl(function(a, b) return a ~ to32(b) end, 0, ...)
end


function bit32.extract(n, field, width)
	n = to32(n)
	field = to32(field)
	if width == nil then width = 1 else width = to32(width) end
	check_field_width(field, width)

	return (n >> field) & low_mask(width)
end


function bit32.replace(n, v, field, width)
	n = to32(n)
	field = to32(field)
	if width == nil then width = 1 else width = to32(width) end
	check_field_width(field, width)

	v = to32(v) & low_mask(width)
	local mask = ~low_mask(width) << field
	return (v << field) | (n & mask)
end


function bit32.lrotate(x, disp)
	x = to32(x)
	disp = toint(disp) % 32
	if disp == 0 then
	return x
	elseif disp < 0 then
	return bit32.rrotate(x, -disp)
	else
	return to32(x << disp) | to32(x >> (32 - disp))
	end
end


function bit32.lshift(x, disp)
	return to32(to32(x) << toint(disp))
end


function bit32.rrotate(x, disp)
	x = to32(x)
	disp = toint(disp) % 32
	if disp == 0 then
	return x
	elseif disp < 0 then
	return bit32.lrotate(x, -disp)
	else
	return to32(x >> disp) | to32(x << (32 - disp))
	end
end


function bit32.rshift(x, disp)
	return to32(to32(x) >> toint(disp))
end

-- SHA-2

-- http://lua-users.org/wiki/SecureHashAlgorithm	
-- The code here was originally written by Roberto Ierusalimschy, and is licensed under MIT (see http://lua-users.org/lists/lua-l/2014-08/msg00628.html) 

-- SHA-256 code in Lua 5.2; based on the pseudo-code from
-- Wikipedia (http://en.wikipedia.org/wiki/SHA-2)


local band, rrotate, bxor, rshift, bnot = bit32.band, bit32.rrotate, bit32.bxor, bit32.rshift, bit32.bnot

local string, setmetatable, assert = string, setmetatable, assert


-- Initialize table of round constants
-- (first 32 bits of the fractional parts of the cube roots of the first
-- 64 primes 2..311):
local k = {
	 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
	 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
	 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
	 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
	 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
	 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
	 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
	 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
	 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}


-- transform a string of bytes in a string of hexadecimal digits
local function str2hexa (s)
	local h = string.gsub(s, ".", function(c)
		return string.format("%02x", string.byte(c))
	end)
	return h
end


-- transform number 'l' in a big-endian sequence of 'n' bytes
-- (coded as a string)
local function num2s (l, n)
	local s = ""
	for i = 1, n do
		local rem = l % 256
		s = string.char(rem) .. s
		l = (l - rem) / 256
	end
	return s
end

-- transform the big-endian sequence of four bytes starting at
-- index 'i' in 's' into a number
local function s232num (s, i)
	local n = 0
	for i = i, i + 3 do
		n = n*256 + string.byte(s, i)
	end
	return n
end


-- append the bit '1' to the message
-- append k bits '0', where k is the minimum number >= 0 such that the
-- resulting message length (in bits) is congruent to 448 (mod 512)
-- append length of message (before pre-processing), in bits, as 64-bit
-- big-endian integer
local function preproc (msg, len)
	local extra = -(len + 1 + 8) % 64
	len = num2s(8 * len, 8)	-- original len in bits, coded
	msg = msg .. "\128" .. string.rep("\0", extra) .. len
	assert(#msg % 64 == 0)
	return msg
end


local function initH224 (H)
	-- (second 32 bits of the fractional parts of the square roots of the
	-- 9th through 16th primes 23..53)
	H[1] = 0xc1059ed8
	H[2] = 0x367cd507
	H[3] = 0x3070dd17
	H[4] = 0xf70e5939
	H[5] = 0xffc00b31
	H[6] = 0x68581511
	H[7] = 0x64f98fa7
	H[8] = 0xbefa4fa4
	return H
end


local function initH256 (H)
	-- (first 32 bits of the fractional parts of the square roots of the
	-- first 8 primes 2..19):
	H[1] = 0x6a09e667
	H[2] = 0xbb67ae85
	H[3] = 0x3c6ef372
	H[4] = 0xa54ff53a
	H[5] = 0x510e527f
	H[6] = 0x9b05688c
	H[7] = 0x1f83d9ab
	H[8] = 0x5be0cd19
	return H
end


local function digestblock (msg, i, H)

	-- break chunk into sixteen 32-bit big-endian words w[1..16]
	local w = {}
	for j = 1, 16 do
		w[j] = s232num(msg, i + (j - 1)*4)
	end

	-- Extend the sixteen 32-bit words into sixty-four 32-bit words:
	for j = 17, 64 do
		local v = w[j - 15]
		local s0 = bxor(rrotate(v, 7), rrotate(v, 18), rshift(v, 3))
		v = w[j - 2]
		local s1 = bxor(rrotate(v, 17), rrotate(v, 19), rshift(v, 10))
		w[j] = w[j - 16] + s0 + w[j - 7] + s1
	end

	-- Initialize hash value for this chunk:
	local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]

	-- Main loop:
	for i = 1, 64 do
		local s0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
		local maj = bxor(band(a, b), band(a, c), band(b, c))
		local t2 = s0 + maj
		local s1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
		local ch = bxor (band(e, f), band(bnot(e), g))
		local t1 = h + s1 + ch + k[i] + w[i]

		h = g
		g = f
		f = e
		e = d + t1
		d = c
		c = b
		b = a
		a = t1 + t2
	end

	-- Add (mod 2^32) this chunk's hash to result so far:
	H[1] = band(H[1] + a)
	H[2] = band(H[2] + b)
	H[3] = band(H[3] + c)
	H[4] = band(H[4] + d)
	H[5] = band(H[5] + e)
	H[6] = band(H[6] + f)
	H[7] = band(H[7] + g)
	H[8] = band(H[8] + h)

end


local function finalresult224 (H)
	-- Produce the final hash value (big-endian):
	return
	str2hexa(num2s(H[1], 4)..num2s(H[2], 4)..num2s(H[3], 4)..num2s(H[4], 4)..
			 num2s(H[5], 4)..num2s(H[6], 4)..num2s(H[7], 4))
end


local function finalresult256 (H)
	-- Produce the final hash value (big-endian):
	return
	str2hexa(num2s(H[1], 4)..num2s(H[2], 4)..num2s(H[3], 4)..num2s(H[4], 4)..
			 num2s(H[5], 4)..num2s(H[6], 4)..num2s(H[7], 4)..num2s(H[8], 4))
end


----------------------------------------------------------------------
local HH = {}	-- to reuse

local function hash224 (msg)
	msg = preproc(msg, #msg)
	local H = initH224(HH)

	-- Process the message in successive 512-bit (64 bytes) chunks:
	for i = 1, #msg, 64 do
	digestblock(msg, i, H)
	end

	return finalresult224(H)
end


local function hash256 (msg)
	msg = preproc(msg, #msg)
	local H = initH256(HH)

	-- Process the message in successive 512-bit (64 bytes) chunks:
	for i = 1, #msg, 64 do
		digestblock(msg, i, H)
	end

	return finalresult256(H)
end
----------------------------------------------------------------------
local mt = {}

local function new256 ()
	local o = {H = initH256({}), msg = "", len = 0}
	setmetatable(o, mt)
	return o
end

mt.__index = mt

function mt:add (m)
	self.msg = self.msg .. m
	self.len = self.len + #m
	local t = 0
	while #self.msg - t >= 64 do
		digestblock(self.msg, t + 1, self.H)
		t = t + 64
	end
	self.msg = self.msg:sub(t + 1, -1)
end


function mt:close ()
	self.msg = preproc(self.msg, self.len)
	self:add("")
	return finalresult256(self.H)
end
----------------------------------------------------------------------

return {
	hash224 = hash224,
	hash256 = hash256,
	new256 = new256,
}