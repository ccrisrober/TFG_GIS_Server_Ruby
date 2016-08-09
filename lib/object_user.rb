=begin
Copyright (c) 2015, maldicion069 (Cristian Rodríguez) <ccrisrober@gmail.con>
//
Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.
//
THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
=end

class ObjectUser
	def initialize(id, x, y)
		@id = id
		@pos_x = x
		@pos_y = y
		@map = 0
		@roll_dice = 0
		@objects = Hash.new
	end #initialize

	def to_json(options = {})
		{"Id" => @id, "PosX" => @pos_x, "PosY" => @pos_y,
			"Map" => @map, "RollDie" => @roll_dice}.to_json
	end # to_json

	attr_accessor :id, :pos_x, :pos_y, :map, :roll_dice

	attr_reader :id, :pos_x, :pos_y, :map, :roll_dice

	def add_object(obj)
		@objects[obj.id] = obj
	end

	def remove_object(id_obj)
		@objects.delete(id_obj)
	end

end # class ObjectUser
