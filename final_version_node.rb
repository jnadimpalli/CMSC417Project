require 'socket'
require 'thread'

$port = nil
$hostname = nil

$server = nil

$nodes = {}

$lsp = {}
$sequencenum = 1

$messages = {}

$table = {}

$pings = Array.new

$trace_hops = Array.new(10)
$trace_time = nil

$updateInterval = nil
$maxPayload = nil
$pingTimeout = nil


# --------------------- Part 0 --------------------- #

def run_server
	# start server
	$server = TCPServer.open($port)

	#create array to keep track of sockets we can read from
	reading = [$server]

	mutex = Mutex.new

	while true
		results = IO.select(reading)

		read = results[0]

		read.each do |socket|
			#Thread::abort_on_exception = true
			listening_thread = Thread.new do
			
				if socket == $server
					# A new client is connecting to server
					client, addr_info = $server.accept_nonblock
					
					mutex.synchronize {
						reading.push(client)
					}

					message = client.gets("\0")

					#STDERR.puts "message read at " + $hostname + ": " + message

					if message != nil
						message = message.chomp
						message_info = message.split(' ')

						message_type = message_info[0]

						case message_type
						# we have to create a symmetric connection to the other server
						when "EDGEB"
							node_name = message_info[1]
							node_ip = message_info[2]

							#update node info
							$nodes[node_name]["IP"] = node_ip
							$nodes[node_name]["COST"] = 1

							dst_port = $nodes[node_name]["PORT"]
							dst_socket = TCPSocket.new(node_ip, dst_port)

							#save destination socket so that you can send messages through here later
							$nodes[node_name]["SOCKET"] = dst_socket
							
							lsp()
						when "LSP"
							#STDERR.puts "In LSP for " + $hostname
	
							#STDERR.puts "message_info: " + message_info
							
							id = message_info[1]
							seqnum = message_info[2].to_i
							cost_string = message_info[3]
							ttl = message_info[4].to_i
							sender = message_info[5]
	
							#STDERR.puts "\"" + message + "\""
							#STDERR.puts "\"" + id + "\""
							#STDERR.puts "\"" + seqnum.to_s + "\""
							#STDERR.puts "\"" + cost_string + "\""
							#STDERR.puts "\"" + ttl.to_s + "\""
							#STDERR.puts "\"" + sender + "\""
							#STDERR.puts "\"" + return_path + "\""
	
							if seqnum > $lsp[id]["NUM"]
								#STDERR.puts "Replacing LSP for " + id + " at " + $hostname
								$lsp[id]["NUM"] = seqnum
								$lsp[id]["TTL"] = ttl
	
								neighbors = cost_string.chomp.strip.split(":")
								neighbors.each do |n|
									#STDERR.puts "n: \"" + n + "\""
	
									node_cost = n.split(",")
									node_neighbor = node_cost[0]
									cost_neighbor = node_cost[1].to_i
	
									#STDERR.puts "neighbor: " + node_neighbor
									#STDERR.puts "cost: " + cost_neighbor.to_s
	
									$lsp[id]["COST"][node_neighbor] = cost_neighbor
								end
	
								new_ttl = ttl -1

								new_message = "LSP " + id + " " + (seqnum).to_s + " " + cost_string + " " + (new_ttl).to_s + " " + $hostname

								$nodes.keys.each do |node|
									if node != sender && $nodes[node]["SOCKET"] != nil && new_ttl >= 0
										#STDERR.puts "LSP from " + id + " is begin sent by #{$hostname} to " + node
		
										socket = $nodes[node]["SOCKET"]
										socket.write("#{new_message} \0")
									end
								end
								#STDERR.puts "SENDING response LSP from #{$hostname} to everyone"
								response_lsp()
							end
						when "RESPONSE_LSP"
							#STDERR.puts "In LSP for " + $hostname
	
							#STDERR.puts "message_info: " + message_info
							
							id = message_info[1]
							seqnum = message_info[2].to_i
							cost_string = message_info[3]
							ttl = message_info[4].to_i
							sender = message_info[5]
	
							#STDERR.puts "\"" + message + "\""
							#STDERR.puts "\"" + id + "\""
							#STDERR.puts "\"" + seqnum.to_s + "\""
							#STDERR.puts "\"" + cost_string + "\""
							#STDERR.puts "\"" + ttl.to_s + "\""
							#STDERR.puts "\"" + sender + "\""
							#STDERR.puts "\"" + return_path + "\""
	
							if seqnum > $lsp[id]["NUM"]
								#STDERR.puts "Replacing (RESPONSE) LSP for " + id + " at " + $hostname
								$lsp[id]["NUM"] = seqnum
								$lsp[id]["TTL"] = ttl
	
								neighbors = cost_string.chomp.strip.split(":")
								neighbors.each do |n|
									#STDERR.puts "n: \"" + n + "\""
	
									node_cost = n.split(",")
									node_neighbor = node_cost[0]
									cost_neighbor = node_cost[1].to_i
	
									#STDERR.puts "neighbor: " + node_neighbor
									#STDERR.puts "cost: " + cost_neighbor.to_s
	
									$lsp[id]["COST"][node_neighbor] = cost_neighbor
								end
	
								new_ttl = ttl -1

								new_message = "RESPONSE_LSP " + id + " " + (seqnum).to_s + " " + cost_string + " " + (new_ttl).to_s + " " + $hostname

								$nodes.keys.each do |node|
									if node != sender && $nodes[node]["SOCKET"] != nil && new_ttl >= 0
										#STDERR.puts "(RESPONSE) LSP from " + id + " is begin sent by #{$hostname} to " + node
		
										socket = $nodes[node]["SOCKET"]
										socket.write("#{new_message} \0")
									end
								end
							end
						end
					end
					client.flush
				else
					# Perform a blocking-read until new-line is encountered.
					# We know the client is writing, so as long as it adheres to the
					# new-line protocol, we shouldn't block for very long.
					
					message = socket.gets("\0")
					message_info = message.split(' ', 2)

					message_type = message_info[0]

					#STDERR.puts message
					#STDERR.puts message_info

					case message_type
					# for this option a client is requesting that we return info about the cost to our neighbors
					when "LSP"
						message = message.chomp
						message_info = message.split(' ')
						
						#STDERR.puts "In LSP for " + $hostname

						#STDERR.puts "message_info: " + message_info
						id = message_info[1]
						seqnum = message_info[2].to_i
						cost_string = message_info[3]
						ttl = message_info[4].to_i
						sender = message_info[5]

						#STDERR.puts "\"" + message + "\""
						#STDERR.puts "\"" + id + "\""
						#STDERR.puts "\"" + seqnum.to_s + "\""
						#STDERR.puts "\"" + cost_string + "\""
						#STDERR.puts "\"" + ttl.to_s + "\""
						#STDERR.puts "\"" + sender + "\""
						#STDERR.puts "\"" + return_path + "\""

						if seqnum > $lsp[id]["NUM"]
							#STDERR.puts "Replacing LSP for " + id + " at " + $hostname
							$lsp[id]["NUM"] = seqnum
							$lsp[id]["TTL"] = ttl

							neighbors = cost_string.chomp.strip.split(":")
							neighbors.each do |n|
								#STDERR.puts "n: \"" + n + "\""

								node_cost = n.split(",")
								node_neighbor = node_cost[0]
								cost_neighbor = node_cost[1].to_i

								#STDERR.puts "neighbor: " + node_neighbor
								#STDERR.puts "cost: " + cost_neighbor.to_s

								$lsp[id]["COST"][node_neighbor] = cost_neighbor
							end

							new_ttl = ttl -1

							new_message = "LSP " + id + " " + (seqnum).to_s + " " + cost_string + " " + (new_ttl).to_s + " " + $hostname

							$nodes.keys.each do |node|
								if node != sender && $nodes[node]["SOCKET"] != nil && node != id && new_ttl >= 0
									#STDERR.puts "LSP from " + id + " is begin sent by #{$hostname} to " + node
	
									socket = $nodes[node]["SOCKET"]
									socket.write("#{new_message} \0")
								end
							end
							
							#STDERR.puts "SENDING response LSP from #{$hostname} to everyone"
							response_lsp()
							
						end
						
					when "RESPONSE_LSP"
						message = message.chomp
						message_info = message.split(' ')
					
						#STDERR.puts "In LSP for " + $hostname

						#STDERR.puts "message_info: " + message_info
						id = message_info[1]
						seqnum = message_info[2].to_i
						cost_string = message_info[3]
						ttl = message_info[4].to_i
						sender = message_info[5]

						#STDERR.puts "\"" + message + "\""
						#STDERR.puts "\"" + id + "\""
						#STDERR.puts "\"" + seqnum.to_s + "\""
						#STDERR.puts "\"" + cost_string + "\""
						#STDERR.puts "\"" + ttl.to_s + "\""
						#STDERR.puts "\"" + sender + "\""
						#STDERR.puts "\"" + return_path + "\""

						if seqnum > $lsp[id]["NUM"]
							#STDERR.puts "Replacing (RESPONSE) LSP for " + id + " at " + $hostname
							$lsp[id]["NUM"] = seqnum
							$lsp[id]["TTL"] = ttl

							neighbors = cost_string.chomp.strip.split(":")
							neighbors.each do |n|
								#STDERR.puts "n: \"" + n + "\""

								node_cost = n.split(",")
								node_neighbor = node_cost[0]
								cost_neighbor = node_cost[1].to_i

								#STDERR.puts "neighbor: " + node_neighbor
								#STDERR.puts "cost: " + cost_neighbor.to_s

								$lsp[id]["COST"][node_neighbor] = cost_neighbor
							end

							new_ttl = ttl -1

							new_message = "RESPONSE_LSP " + id + " " + (seqnum).to_s + " " + cost_string + " " + (new_ttl).to_s + " " + $hostname

							$nodes.keys.each do |node|
								if node != sender && $nodes[node]["SOCKET"] != nil && node != id && new_ttl >= 0
									#STDERR.puts "(RESPONSE) LSP from " + id + " is begin sent by #{$hostname} to " + node
	
									socket = $nodes[node]["SOCKET"]
									socket.write("#{new_message} \0")
								end
							end
						end
						
					when "SNDMSG"
						message_info = message.split(',')
						
						sender = message_info[1]
						reciever = message_info[2]
						frag_num = message_info[3]
						tot_frag = message_info[4]
						message_frag = message_info[5]
						
						if reciever != $hostname 
							dijkstras($hostname)
							next_node = $table[reciever]["NEXT"]
							
							frag_string = "SNDMSG ,#{sender},#{reciever},#{frag_num},#{tot_frag},#{message_frag}"
							$nodes[next_node]["SOCKET"].write("#{frag_string}\0")
						else
							
							if $messages[sender]["STATUS"] == "FULL"
								arr = Array.new(tot_frag.to_i)
								$messages[sender]["MESSAGE"] = arr
							end
							
							$messages[sender]["MESSAGE"][(frag_num.to_i - 1)] = message_frag
							
							partial = $messages[sender]["MESSAGE"].any?{ |e| e.nil? }
							
							if partial == true
								$messages[sender]["STATUS"] = "PARTIAL"
							else 
								$messages[sender]["STATUS"] = "FULL"
							end
							
							#STDERR.puts message_frag
							#full_message = $messages[sender]["MESSAGE"].join("")
							#STDERR.puts full_message
							#STDERR.puts $messages[sender]["STATUS"]
							
							if $messages[sender]["STATUS"] == "FULL"
								full_message = $messages[sender]["MESSAGE"].join("")
								full_message = full_message+"\""
								#STDERR.puts "Finished combining message"
								#STDERR.puts "Here is message #{full_message}"
								STDOUT.puts 'SNDMSG: ' + sender + " −− > \"#{full_message}\""
							end
							
						end
						
					when "PING_REQ"
						message = message.chomp
						message_info = message.split(' ')
						
						id = message_info[1]
						sender = message_info[2]
						dst = message_info[3]
						reciever = dst
						
						#STDERR.puts $hostname + " == " + dst + "?"
						
						#STDERR.puts $hostname.inspect
						#STDERR.puts reciever.inspect
						
						if reciever == $hostname
							dijkstras($hostname)
							#STDERR.puts "YES"	
							next_node = $table[sender]["NEXT"]
							
							ping_string = "PING_RES #{id} #{$hostname} #{sender}"
							$nodes[next_node]["SOCKET"].write("#{ping_string} \0")
							
							#STDERR.puts "SENT RESPONSE PING TO #{sender}"
						else 
							dijkstras($hostname)
							#STDERR.puts "NO"
							
							next_node = $table[reciever]["NEXT"]
							
							ping_string = "PING_REQ #{id} #{sender} #{reciever}"
							$nodes[next_node]["SOCKET"].write("#{ping_string} \0")
							
							#STDERR.puts "SENT Ping to #{next_node}"
						end
						#STDERR.puts "END of PING REQUEST"
						
					when "PING_RES"
						message = message.chomp
						message_info = message.split(' ')
					
						#STDERR.puts "In LSP for " + $hostname

						#STDERR.puts "id = message_info[1]
						id = message_info[1]
						sender = message_info[2]
						dst = message_info[3]
						reciever = dst
						
						#STDERR.puts "RESPONSE           " + $hostname + " == " + reciever + " ?"
						
						if reciever == $hostname
							dijkstras($hostname)
							#STDERR.puts "YES"
							
							$pings.each do |ping|
								#STDERR.puts ping[0].inspect
								#STDERR.puts id.inspect
								#STDERR.puts ping[1].inspect
								#STDERR.puts reciever.inspect
								if ping[0] == id.to_i && ping[1] == reciever && ping[2] == sender
									#STDERR.puts "FOUND PING"
									ping[4] = Time.now
									
									time_diff = ping[4] - ping[3]
									#STDERR.puts time_diff
									#STDERR.puts "#{id.to_i} #{sender} #{time_diff.to_i}"
									STDOUT.puts "#{id.to_i} #{sender} #{time_diff.to_i}"
								end
							end
							
						else 
							dijkstras($hostname)
							#STDERR.puts "NO"
							
							next_node = $table[reciever]["NEXT"]
							
							ping_string = "PING_RES #{id} #{sender} #{reciever}"
							$nodes[next_node]["SOCKET"].write("#{ping_string} \0")
							
							#STDERR.puts "SENT Ping to #{next_node}"
						end
						#STDERR.puts "END of PING RESPONSE"
						
						
					when "TRACE_REQ"
					
						message = message.chomp
						message_info = message.split(' ')
					
						#STDERR.puts "In LSP for " + $hostname

						#STDERR.puts id = message_info[1]
						id = message_info[1]
						sender = message_info[2]
						dst = message_info[3]
						reciever = dst
						
						dijkstras($hostname)
						
						response_string = "TRACE_RES #{id.to_i} #{$hostname} #{sender}"
						next_node = $table[sender]["NEXT"]
						$nodes[next_node]["SOCKET"].write("#{response_string} \0")
						#STDERR.puts "SENT RESPONSE #{id}"
						
						if reciever != $hostname
							next_node = $table[reciever]["NEXT"]
							request_string = "TRACE_REQ #{(id.to_i)+1} #{sender} #{reciever}"
							$nodes[next_node]["SOCKET"].write("#{request_string} \0")
						end
						
						#STDERR.puts "#{id.to_i} #{sender} #{reciever}"
						
					when "TRACE_RES"
					
						message = message.chomp
						message_info = message.split(' ')
					
						#STDERR.puts "In LSP for " + $hostname

						#STDERR.puts id = message_info[1]
						id = message_info[1].to_i
						sender = message_info[2]
						dst = message_info[3]
						reciever = dst
						
						dijkstras($hostname)
						
						#STDERR.puts "GOT RESPONSE BACK #{id} at #{$hostname}"
						
						if reciever == $hostname
							
							time_now = Time.now
							
							time_diff = time_now - $trace_time
							time_diff = time_diff.to_i
							
							$trace_hops[id] = "#{id} #{sender} #{time_diff}"
							#STDERR.puts $trace_hops[id]
						else 					
							next_node = $table[reciever]["NEXT"]		
							response_string = "TRACE_RES #{id} #{sender} #{reciever}"
							$nodes[next_node]["SOCKET"].write("#{response_string} \0")
							#STDERR.puts "PASSED RESPONSE #{id} ALONG"
						end
						
					end
					# end of case statement
					
				end
				#end of if/else statement
				
			end
			#end of thread statement
			
		end
		#end of IO.select statement
		
	end
	#end of while loop
	
end

def edgeb(cmd)
	src_ip = cmd[0]
	dst_ip = cmd[1]

	dst_name = cmd[2]
	dst_port = $nodes[dst_name]["PORT"]


	#update cost and ip information
	$nodes[dst_name]["COST"] = 1
	$nodes[dst_name]["IP"] = dst_ip

	# connect to server and tell it who is connecting to it
	dst_socket = TCPSocket.new(dst_ip, dst_port)
	dst_socket.write("EDGEB #{$hostname} #{src_ip} \0")
	dst_socket.flush

	#save destination socket so that you can send messages through here later
	$nodes[dst_name]["SOCKET"] = dst_socket

	lsp()
end

def dumptable(cmd)

	dijkstras($hostname)

	filename = cmd[0].split("./")[1]

	# for each node, check to see if a positive non-zero COST exists.
	# If so, add to file in order: src,dst,nextHop,distance
	dumptable_string = ""

	$table.keys.each do |node|
		#STDERR.puts node
		if ((node != $hostname) && ($table[node]["COST"] > 0) && ($table[node]["COST"] != Float::INFINITY))
			dumptable_string += $hostname + "," + node + "," + $table[node]["NEXT"] + "," + $table[node]["COST"].to_s + "\n"
		end
	end

	File.open(filename, "w") {|f|
		f.write(dumptable_string)
	}
end

def shutdown(cmd)
	$server.close
	STDOUT.flush
	STDERR.flush
	exit(0)
end



# --------------------- Part 1 --------------------- #
def edged(cmd)
	dst_name = cmd[0]
	dst_socket = $nodes[dst_name]["SOCKET"]

	dst_socket.close
	$nodes[dst_name]["SOCKET"] = nil
	$nodes[dst_name]["COST"] = -1

	lsp()
end

def edgeu(cmd)
	dst_name = cmd[0]
	cost = cmd[1]

	if !dst_name.empty? && !cost.empty?
		if (dst_name.is_a? String) && (cost.to_i.is_a? Integer)
			$nodes[dst_name]["COST"] = cost.to_i
		end
	end
	
	lsp()
end

def status()

	dijkstras($hostname)
	
	STDOUT.puts "Name: #{$hostname}"
	STDOUT.puts "Port: #{$nodes[$hostname]["PORT"]}"
	
	nodes_list = []
	
	$table.keys.each do |node|
		STDERR.puts node
		if node != $hostname && $table[node]["COST"] > 0
			nodes_list.push(node)
		end
	end
	
	nodes_list.sort!
	
	nodes_string = ""
	
	nodes_list.each { |node|
		nodes_string << node+","
	}
	
	nodes_string.chomp(",")
	
	STDOUT.puts "Neighbors: #{nodes_string}"
end

def dijkstras(source)
	unvisited = []
	min_node = nil

	$nodes.keys.each do |node|
		#table[node]["COST"] represents the distance array
		#table[node]["PREV"] represents the previous array

		$table[node]["COST"] = Float::INFINITY
		$table[node]["PREV"] = nil
		unvisited.push(node)
	end

	$table[source]["COST"] = 0

	while !unvisited.empty?
		min_value = Float::INFINITY

		has_nodes_with_edges = false
		unvisited.each { |node|
			if $table[node]["COST"] != min_value
				has_nodes_with_edges = true
			end
		}
		
		if !has_nodes_with_edges
			break
		end

		$table.keys.each do |node|
			if unvisited.include? node
				if $table[node]["COST"] < min_value
					min_value = $table[node]["COST"]
					min_node = node
				end
			end
		end
		
		unvisited.delete(min_node)
		
		$lsp[min_node]["COST"].keys.each do |v|
			alt_cost = min_value + $lsp[min_node]["COST"][v].to_i
			
			if alt_cost < $table[v]["COST"]
				$table[v]["COST"] = alt_cost
				$table[v]["PREV"] = min_node
			end
		end
	end

	$table.keys.each do |node|
		if $table[node]["PREV"] != nil
			curr_node = node
			prev_node = $table[node]["PREV"]

			while prev_node != $hostname
				curr_node = prev_node
				prev_node = $table[curr_node]["PREV"]
			end

			$table[node]["NEXT"] = curr_node
		end
	end
end

def lsp()

	cost_string = ""

	$nodes.each do |key, value|
		cost = value["COST"].to_s
		if (cost.to_i) > 0
			cost_string << key.to_s + "," + cost + ":"
		end
	end

	ttl = $nodes.keys.count

	lsp_string = "LSP " + $hostname + " #{$sequencenum} " + cost_string + " #{ttl} " + $hostname
	
	#STDERR.puts "#{lsp_string} is being sent from #{$hostname}"

	$lsp[$hostname]["NUM"] = $sequencenum
	$lsp[$hostname]["TTL"] = ttl
	$lsp[$hostname]["COST"] = {}
	
	$nodes.keys.each do |node|
		if $nodes[node]["COST"] > 0
			$lsp[$hostname]["COST"][node] = $nodes[node]["COST"]
		end
	end

	$nodes.each do |key, value|
		socket = value["SOCKET"]
		if socket != nil
			socket.write("#{lsp_string} \0")
		end
	end

	$sequencenum += 1
end

def response_lsp()

	cost_string = ""

	$nodes.each do |key, value|
		cost = value["COST"].to_s
		if (cost.to_i) > 0
			cost_string << key.to_s + "," + cost + ":"
		end
	end

	ttl = $nodes.keys.count

	lsp_string = "RESPONSE_LSP " + $hostname + " #{$sequencenum} " + cost_string + " #{ttl} " + $hostname
	
	#STDERR.puts "#{lsp_string} is being sent from #{$hostname}"

	$lsp[$hostname]["NUM"] = $sequencenum
	$lsp[$hostname]["TTL"] = ttl
	$lsp[$hostname]["COST"] = {}
	
	$nodes.keys.each do |node|
		if $nodes[node]["COST"] > 0
			$lsp[$hostname]["COST"][node] = $nodes[node]["COST"]
		end
	end

	$nodes.each do |key, value|
		socket = value["SOCKET"]
		if socket != nil
			socket.write("#{lsp_string} \0")
		end
	end

	$sequencenum += 1
end

def get_farthest_node()
	dijkstras($hostname)

	max_cost = -1

	$table.keys.each do |node|
		if $table[node]["PREV"] != nil 
			if max_cost < $table[node]["COST"]
				max_cost = $table[node]["COST"]
			end
		end
	end

	if max_cost == -1
		max_cost = 1
	end

	return max_cost
end

# -------- Part 2 ------- #
def sendmsg(cmd, message)
	dijkstras($hostname)
	
	dst_name = cmd[0]
	next_node = $table[dst_name]["NEXT"]
	
	if next_node == nil
		STDOUT.puts "SNDMSG ERROR: HOST UNREACHABLE"
	end
	
	messageFrag = Array.new
	index = 0
	
	while message.length > $maxPayload
		messageFrag[index] = message[0..($maxPayload-1)]
		message = message[$maxPayload..-1]
		index = index+1
	end
	
	messageFrag[index] = message
	
	tot_frags = index+1
	frag_index = 1
	
	messageFrag.each do |m|
	
		frag_string = "SNDMSG ,#{$hostname},#{dst_name},#{frag_index},#{tot_frags},#{m}"
	
		$nodes[next_node]["SOCKET"].write("#{frag_string}\0")
		frag_index = frag_index + 1
	end
	
end

def ping(cmd)
	dijkstras($hostname)
	
	dst_name = cmd[0]
	num_pings = cmd[1].to_i
	delay = cmd[2].to_i
	
	for i in 0..(num_pings-1)
		sleep delay
		p = [i, $hostname, dst_name, Time.now, nil]
		$pings.push(p)
		
		#send ping
		next_node = $table[dst_name]["NEXT"]
		#STDERR.puts $table
		#STDERR.puts dst_name
		#STDERR.puts next_node	
		
		if next_node == nil
			STDOUT.puts "PING ERROR: HOST UNREACHABLE"
			#STDERR.puts "PING ERROR: HOST UNREACHABLE"
			
			next
		end
		
		#STDERR.puts next_node
			
		ping_string = "PING_REQ #{i} #{$hostname} #{dst_name}"
		$nodes[next_node]["SOCKET"].write("#{ping_string} \0")

		timer = Thread.new { 
			timeout_p = [p[0], $hostname, dst_name, p[3], nil]
			
			sleep $pingTimeout
			
			if $pings.include? timeout_p
				$pings.delete(timeout_p)
				#STDERR.puts "PING #{timeout_p[0]} TIMEOUT"
				STDOUT.puts "PING ERROR: HOST UNREACHABLE"
			end
		}
		
		#STDERR.puts $pings.length
	end
end

def traceroute(cmd)
	dijkstras($hostname)
	
	dst_name = cmd[0]
	
	$trace_hops = Array.new(11)
	$trace_index = 0
	
	$trace_hops[0] = "0 #{$hostname} 0"
	$trace_time = Time.now
	
	for i in 1..9
		$trace_hops[i] = nil
	end
	
	next_node = $table[dst_name]["NEXT"]
	#STDERR.puts next_node
	max_hops = $table[dst_name]["COST"]
	
	if next_node == nil
		for i in 1..9
			STDOUT.puts "TIMEOUT on #{i}"
			#STDERR.puts "TIMEOUT on #{i}"
		end
		
		return
	end
	
	trace_string = "TRACE_REQ 1 #{$hostname} #{dst_name}"
	$nodes[next_node]["SOCKET"].write("#{trace_string} \0")
	#STDERR.puts "SENT TRACE"
	
	timer = Thread.new {			
			sleep $pingTimeout
			
			error_index = -1
			
			for i in 0..max_hops
				if $trace_hops[i] == nil
					error_index = i
				end
			end
			
			if error_index != -1
				for i in 0..error_index
					STDOUT.puts $trace_hops[i]
					#STDERR.puts $trace_hops[i]
				end
				
				for i in error_index..9
					STDOUT.puts "TIMEOUT on #{i}"
					#STDERR.puts "TIMEOUT on #{i}"
				end
			else 
				for i in 0..max_hops
					STDOUT.puts $trace_hops[i]
					#STDERR.puts $trace_hops[i]
				end
			end
			
			#STDERR.puts "KILL THREAD BEGIN"
			#STDERR.puts $trace_hops
			#STDERR.puts "KILL THREAD END"
		}
end

def ftp(cmd)
	STDOUT.puts "FTP: not implemented"
end

# --------------------- Part 3 --------------------- #
def circuit(cmd)
	STDOUT.puts "CIRCUIT: not implemented"
end

def test()
	dijkstras($hostname)
	STDERR.puts $lsp
	STDERR.puts $table
end



# do main loop here....
def main()
	while(line = STDIN.gets())
		line = line.strip()
		params, message = line.split('"')
		arr = params.split(' ')
		cmd = arr[0]
		args = arr[1..-1]
		case cmd
		when "EDGEB"
			edgeb(args)
		when "EDGED"
			edged(args)
		when "EDGEU"
			edgeu(args)
		when "DUMPTABLE"
			dumptable(args)
		when "SHUTDOWN"
			shutdown(args)
		when "STATUS"
			lsp()
		when "SNDMSG"
			sendmsg(args, message)
		when "PING"
			ping(args)
		when "TRACEROUTE"
			traceroute(args)
		when "TEST"
			test()
		else
			STDERR.puts "ERROR: INVALID COMMAND \"#{cmd}\""
		end
	end

end

def setup(hostname, port, nodes, config)
	$hostname = hostname
	$port = port

	# keep track of all nodes in hashtable
	fHandle = File.open(nodes)
	while(line = fHandle.gets())
		arr = line.chomp.split(',')

		node_name = arr[0]
		node_port = arr[1]

		$nodes[node_name] = {}
		$nodes[node_name]["IP"] = nil
		$nodes[node_name]["SOCKET"] = nil
		$nodes[node_name]["PORT"] = node_port.to_i
		# 0 is self, -1 is unreachable (infinity)
		$nodes[node_name]["COST"] = -1
		if node_name == $hostname
			$nodes[node_name]["COST"] = 0
		end

		$lsp[node_name] = {}
		$lsp[node_name]["NUM"] = -1
		$lsp[node_name]["TTL"] = -1
		$lsp[node_name]["COST"] = Hash.new

		$table[node_name] = {}
		$table[node_name]["PREV"] = nil
		$table[node_name]["COST"] = -1
		$table[node_name]["NEXT"] = nil
		if node_name == $hostname
			$table[node_name]["COST"] = 0
		end
		
		$messages[node_name] = {}
		$messages[node_name]["MESSAGE"] = Array.new
		$messages[node_name]["STATUS"] = "FULL"
	end

	#STDERR.puts $table

	#keep track of config variables
	fHandle = File.open(config)
	while(line = fHandle.gets())
		arr = line.chomp().split('=')

		value_type = arr[0].strip()
		value = arr[1].strip()

		case value_type
		when "updateInterval"
			$updateInterval = value.to_i
		when "maxPayload"
			$maxPayload = value.to_i
		when "pingTimeout"
			$pingTimeout = value.to_i
		end

	end
	
	# start separate server thread
	server_thread = Thread.new do
		run_server()
	end

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])