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
require "socket"
require "json"
require_relative "key_object"
require_relative "map"
require_relative "object_user"
#https://www6.software.ibm.com/developerworks/education/l-rubysocks/l-rubysocks-a4.pdf
class ChatServer
	def initialize( port )
		@descriptors = Array::new
		@serverSocket = TCPServer.new( "", port )
		@serverSocket.setsockopt( Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1 )
		@descriptors.push( @serverSocket )
		@positions = Hash.new
    @objects = Hash.new

    @objects["Red"] = KeyObject.new(1, 5*64, 5*64, "Red")
    @objects["Blue"] = KeyObject.new(2, 6*64, 5*64, "Blue")
    @objects["Yellow"] = KeyObject.new(3, 7*64, 5*64, "Yellow")
    @objects["Green"] = KeyObject.new(4, 8*64, 5*64, "Green")

		@maps = Array::new

    map = ""
    keys = Hash.new

    f = File.read("data.json")
    data_hash = JSON.parse(f)

    data_hash["map"].each do |child|
      map += child
    end

    data_hash["keys"].each do |key|
      keys[key] = @objects[key]
    end

    @maps.push(Map.new(data_hash["id"], map, data_hash["width"], data_hash["height"], keys ))

		printf("Chatserver started on port %d\n", port)

	end # initialize

  def send_position(socket)
    socket.write(@positions[socket.peeraddr[1]].to_json)
  end

  def random_value(min, max)
    rand(max - min) + min
  end

  def send_die_player_and_winner_to_show(sock, receiver_id)
    emisor_id = sock.peeraddr[1]
    # And the winner is ...
    winner = -1
    value_c = -1
    value_e = -1
    if !@positions.has_key?(receiver_id) then
      winner = emisor_id
      value_e = @positions[emisor_id].roll_dice
    elsif !@positions.has_key?(emisor_id) then
      winner = receiver_id
      value_c = @positions[receiver_id].roll_dice
    elsif @positions[emisor_id].roll_dice > @positions[receiver_id].roll_dice then
      winner = emisor_id
      value_e = @positions[emisor_id].roll_dice
      value_c = @positions[receiver_id].roll_dice
    elsif @positions[receiver_id].roll_dice > @positions[emisor_id].roll_dice then
      winner = receiver_id
      value_e = @positions[emisor_id].roll_dice
      value_c = @positions[receiver_id].roll_dice
    end

    ret = {"Action" => "finishBattle", "ValueClient" => value_c, "ValueEnemy" => value_e, "Winner" => winner}.to_json
    sock.write(ret)
  end

  def send_fight_to_another_client(sock, receiver_id)
    emisor_id = sock.peeraddr[1]
    ret_others = {"Action" => "hide", "Ids" => [emisor_id, receiver_id]}.to_json

    # Save die roll value from emisor_id
    @positions[emisor_id].roll_dice = random_value(1, 6)

    @descriptors.each do |client|
			if client != @serverSocket then
        if client.peeraddr[1] == receiver_id then
          ret = {"Action" => "fight", "Id_enemy" => emisor_id}.to_json
          @positions[receiver_id].roll_dice = random_value(1, 6)
          client.write(ret)
        else
          # Otherwise, we send a message to hide the fighters
          client.write(ret_others)
        end
			end
		end
  end

	def run
		while 1
			res = select( @descriptors, nil, nil, nil )
			if res != nil then
				# Iterate through the tagged read descriptors
				for sock in res[0]
					# Received a connect to the server (listening) socket
					if sock == @serverSocket then
						accept_new_connection
					else
						puts sock.peeraddr[1]
						# Received something on a client socket
						if sock.eof? then
              				str = sprintf('{"Action": "exit", "Id": %d}', sock.peeraddr[1])
							# puts str
              				broadcast_string( str, sock )
              				@positions.delete(sock.peeraddr[1])
							sock.close
							@descriptors.delete(sock)
						else
							msg = sock.gets()

							# puts sprintf("%d => %s", sock.peeraddr[1], msg)
							begin
								parsed = JSON.parse(msg)
								action = parsed["Action"]

								if action.eql? "move" then
									@positions[sock.peeraddr[1]].pos_x = parsed["PosX"]
									@positions[sock.peeraddr[1]].pos_y = parsed["PosY"]
								elsif action.eql? "position" then
									send_position(sock)
									next
								elsif action.eql? "fight" then
									send_fight_to_another_client(sock, parsed["Id_enemy"])
									next
								elsif action.eql? "finishBattle" then
									send_die_player_and_winner_to_show(sock, parsed["Id_enemy"])
									next
								elsif action.eql? "getObj" then
									parsed["Action"] = "remObj"
									ret = @maps[0].remove_key(parsed["Id_obj"])
									# puts ret
									@positions[sock.peeraddr[1]].add_object(ret)
									parsed.delete("Id_user")
									msg = parsed.to_json
								elsif action.eql? "freeObj" then
									parsed["Action"] = "addObj"
									obj = @maps[0].add_key(parsed["Obj"]["Id_obj"], parsed["Obj"]["PosX"], parsed["Obj"]["PosY"])
									@positions[sock.peeraddr[1]].remove_object(parsed["Obj"]["Id_obj"])
									parsed.delete("Id_user")
									msg = parsed.to_json
								elsif action.eql? "exit" then
									msg = sprintf('{"Action": "exit", "Id": %d}', sock.peeraddr[1])
									# puts "Desconecto!"
									@positions.delete(sock.peeraddr[1])
									sock.close
									broadcast_string( msg, sock )
									@descriptors.delete(sock)
									next
								end
							rescue Exception => e
								puts e
							end
							broadcast_string( msg, sock )
						end
					end
				end
			end
		end
	end #run

	private

	def broadcast_string( str, omit_sock )
		# puts "Empiezo broadcast"
		@descriptors.each do |client|
			if client != @serverSocket && client != omit_sock
				client.write(str)
			end
		end
		print(str)
	end # broadcast_string

	def accept_new_connection
		newsock = @serverSocket.accept

		@descriptors.push( newsock )

		# Create ObjectUser and save into positions
		id = newsock.peeraddr[1]
		@positions[id] = ObjectUser.new(id, "320", "320")
		puts sprintf("Hay %d clientes y %d posiciones\n", @descriptors.length-1, @positions.length)  #QUEDA ENVIAR LOS OBJETOS!!
		newsock.write({"Action" => "sendMap", "Map" => @maps[0],
			"X" => 5*64, "Y" =>  5*64, "Id" => newsock.peeraddr[1],
			"Objects" => [], "Users" => @positions}.to_json)
		j_others = @positions[id]
		broadcast_string( {"Action" => "new", "Id" => j_others.id,
			"X" => j_others.pos_x.to_f, "Y" => j_others.pos_y.to_f}.to_json,
			newsock )
	end # accept_new_connection
end #server

#def without_gc
#GC.start # start out clean
#GC.disable
#yield
#GC.enable
#end
#
#without_gc do
#Benchmark.measure { some_code }
#end
#GC.start # start out clean
#GC.disable
ChatServer.new( 8089 ).run
