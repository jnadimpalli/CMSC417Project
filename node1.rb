require 'socket'

$port = nil
$hostname = nil

$server = nil

$nodes = {}
$lsp = {}
$table = {}
$sequencenum = 1

$updateInterval = nil
$maxPayload = nil
$pingTimeout = nil


# --------------------- Part 0 --------------------- #

def run_server
	# start server
	$server = TCPServer.open($port)

	#create array to keep track of sockets we can read from
	reading = [$server]

	while true
		results = IO.select(reading)

		read = results[0]

		read.each do |socket|
        	if socket == $server
           		# A new client is connecting to server
	        	client, addr_info = $server.accept_nonblock
	        	reading.push(client)

				message = client.gets("\0")

				STDERR.puts "message read at " + $hostname + ": " + message

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

						#STDERR.puts $nodes
						STDERR.puts "Leaving EDGEB at " + $hostname
						#STDERR.puts $nodes
					end
				end
				client.flush
	        else
	            # Perform a blocking-read until new-line is encountered.
	            # We know the client is writing, so as long as it adheres to the
	            # new-line protocol, we shouldn't block for very long.
	            STDERR.puts "Reading..."
	            message = socket.gets("\0")
				message = message.chomp
				message_info = message.split(' ')

				message_type = message_info[0]

				#STDERR.puts message
				#STDERR.puts message_info

				case message_type
				# for this option a client is requesting that we return info about the cost to our neighbors
				when "COST"
					STDERR.puts "In COST for " + $hostname

					status()
					STDERR.puts "Entered status()"

					# #STDERR.puts $nodes
					# cost_string = ""
					# return_node = message_info[1]
					#
					# STDERR.puts "return: " + return_node
					# STDERR.puts $nodes
					# #STDERR.puts "socket: " + $nodes[return_node] ["SOCKET"]
					#
					# STDERR.puts "Received COST request in " + $hostname + " from " + return_node
					# # return cost to all other nodes that are not the hostname
					# $nodes.keys.each do |node|
					# 	if node != $hostname
					# 		cost_string += node + "," + $nodes[node]["COST"].to_s + " "
					# 	end
					# end
					#
					# #cost_string += "\000"
					# STDERR.puts "cost_string_sent: " + cost_string
					# client.write(cost_string.chomp + " \0")
					# STDERR.puts "Writing cost_string to socket"
				when "LSP"
					STDERR.puts "In LSP for " + $hostname

					#STDERR.puts "message_info: " + message_info
					#info = message_info.chomp.strip.split(" ")
					id = message_info[1]
					seqnum = message_info[2].to_i
					cost_string = message_info[3]
					ttl = message_info[4].to_i
					# return_path = info[4]

					STDERR.puts "\"" + message + "\""
					STDERR.puts "\"" + id + "\""
					STDERR.puts "\"" + seqnum.to_s + "\""
					STDERR.puts "\"" + cost_string + "\""
					STDERR.puts "\"" + ttl.to_s + "\""
					#STDERR.puts "\"" + return_path + "\""

					STDERR.puts "Passing LSP to all neighbors"
					$nodes.keys.each do |node|
						STDERR.puts node
						STDERR.puts $nodes[node]["SOCKET"]
						if node != id && $nodes[node]["SOCKET"] != nil
							STDERR.puts "LSP from " + id + " sent to " + node

							socket = $nodes[node]["SOCKET"]
							socket.write(message)
						end
					end



					if seqnum > $lsp[id]["NUM"]
						STDERR.puts "Replacing LSP for " + id + " at " + $hostname
						$lsp[id]["NUM"] = seqnum
						$lsp[id]["TTL"] = ttl

						neighbors = cost_string.chomp.strip.split(":")
						neighbors.each do |n|
							STDERR.puts "n: \"" + n + "\""

							node_cost = n.split(",")
							node_neighbor = node_cost[0]
							cost_neighbor = node_cost[1].to_i

							#STDERR.puts "neighbor: " + node_neighbor
							#STDERR.puts "cost: " + cost_neighbor.to_s

							$lsp[id]["COST"][node_neighbor] = cost_neighbor
						end
					end



					 STDERR.puts $lsp

					 status()
					#
					#
					#
					# $nodes.keys.each do |node|
					# 	STDERR.puts id
					# 	STDERR.puts $nodes[node]["SOCKET"]
					# 	if node != id && $nodes[node]["SOCKET"] != nil
					# 		STDERR.puts "COST sent to " + node
					#
					# 		socket = $nodes[node]["SOCKET"]
					# 		socket.write("COST \0")
					# 	end
					# end

					# STDERR.puts "cost_string: " + cost_string
					#
					# return_path += $hostname + ","
					# STDERR.puts "new_return: " + return_path
					#
					# # lsp = id sequencenum cost_string TTL return_path
					# lsp_string = $hostname + " " + $sequencenum.to_s + " " + cost_string.chomp(":") + " " + ttl.to_s + " " + return_path
					#
					# $sequencenum = $sequencenum + 1
					#
					# #cost_string += "\000"
					# STDERR.puts "lsp_string_sent: " + lsp_string
					# socket.write(lsp_string.chomp + " \0")
					# STDERR.puts "Writing lsp_string to socket"
					#
					# $nodes.keys.each do |node|
					#     if $nodes[node]["COST"] > 0 && node !=
					# 		socket = $nodes[node]["SOCKET"]
					# 		socket.write("LSP #{$hostname},#{return_path} \0")
					# 	end
					#  	end

					STDERR.puts "Flood"
				end
	    	end
		end
	end
end

def edgeb(cmd)
	src_ip = cmd[0]
	dst_ip = cmd[1]

	dst_name = cmd[2]
	dst_port = $nodes[dst_name]["PORT"]


	#update cost and ip information
	$nodes[dst_name]["COST"] = 1
	$nodes[dst_name]["IP"] = dst_ip

	#$nodes[$hostname]["IP"] = src_ip

	# connect to server and tell it who is connecting to it
	dst_socket = TCPSocket.new(dst_ip, dst_port)
	dst_socket.write("EDGEB #{$hostname} #{src_ip} \0")
	dst_socket.flush
	#dst_socket.write("EDGEB #{$hostname} #{src_ip}\000")
	#dst_socket.send("EDGEB #{$hostname} #{src_ip}\000", 0)

	#save destination socket so that you can send messages through here later
	$nodes[dst_name]["SOCKET"] = dst_socket
	STDERR.puts "Client EDGEB complete at " + $hostname
end

def dumptable(cmd)
	filename = cmd[0].split("./")[1]

	# for each node, check to see if a positive non-zero COST exists.
	# If so, add to file in order: src,dst,nextHop,distance
	dumptable_string = ""
	$nodes.keys.each do |node|
	    if $nodes[node]["COST"] > 0
	    	dumptable_string += $hostname + "," + node + "," + node + "," + $nodes[node]["COST"].to_s + "\n"
	    end
  	end

	File.open(filename, "w") {|f|
		f.write(dumptable_string.chomp)
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
end

def edgeu(cmd)
	dst_name = cmd[0]
	cost = cmd[1]

	if !dst_name.empty? && !cost.empty?
		if (dst_name.is_a? String) && (cost.to_i.is_a? Integer)
			$nodes[dst_name]["COST"] = cost.to_i
		end
	end
end

def dijkstras(source)
	unvisited = []
	distance = []
	previous = []
	min_value = Float::INFINITY
	min_node = nil

	$nodes.keys.each do |node|
		distance[node] = Float::INFINITY
		previous[node] = nil
		unvisited.add(node)
	end

	distance[source] = 0

	while !unvisited.empty
		distance.values.each do |value|
			if value < min
				min = value
			end
		end

		distance.keys.each do |node|
			if distance[node] = min
				min_node = node
				unvisited.delete(min_node)
			end
		end

		$lsp.keys.each do |neighbor|
			STDERR.puts neighbor
			# if $nodes[neighbor]["COST"] > 0
			# 	temp = distance[node] + $nodes[neighbor]["COST"]
			# 	if temp < distance[node]
			# 		distance[neighbor] = temp
			# 		prev[neighbor] = node
			# 	end
			# end
		end
	end
end
=begin
def status1()

	stack = [$hostname]
	visited = []

	STDERR.puts $nodes
	# perform DFS to find all possible routes
	while !stack.empty?
		current_node = stack.pop
		if !visited.include? current_node
			visited.push(current_node)
			STDERR.puts "Visited " + current_node
			# if current_node is not the host, request COST message to build routing table
			if current_node != $hostname
				if $nodes[current_node]["SOCKET"] != nil
					socket = $nodes[current_node]["SOCKET"]
					#STDERR.puts "IP: " + $nodes[current_node]["IP"]
					#STDERR.puts "PORT: " + $nodes[current_node]["PORT"].to_s

					#socket = TCPSocket.new($nodes[current_node]["IP"], $nodes[current_node]["PORT"])
					#socket.send("COST #{$hostname}\000", 0)
					socket.write("COST #{$hostname} \0")
					# socket.puts("COST #{$hostname}")
					#socket.send("COST #{$hostname} \000", 0)


					STDERR.puts "COST message sent to " + current_node

					# gets/recv/read do not seem to be reading the string back from the socket after using write
					cost_string = socket.gets("\0")
					#cost_string = socket.read()
					#cost_string = socket.recv_nonblock($maxPayload)
					#cost_string = socket.recv(16)
					socket.flush

					# code does not reach this point
					STDERR.puts "cost_string_recv: \"" + cost_string + "\""

					STDERR.puts "Parsing cost_string"
					neighbors = cost_string.chomp.strip.split(" ")
					neighbors.each do |n|
						STDERR.puts "n: \"" + n + "\""

						node_cost = n.split(",")
						node_neighbor = node_cost[0]
						cost_neighbor = node_cost[1].to_i

						# STDERR.puts "neighbor: " + node_neighbor
						# STDERR.puts "cost: " + cost_neighbor.to_s
						# STDERR.puts node_neighbor.length > 0
						# STDERR.puts node_neighbor.length > 1
						# add children of current_node to stack for processing
						stack.push(node_neighbor)
						# if route was previously unreachable (-1) or if new route has lower cost, update cost in host's routing table
						STDERR.puts "current: " + current_node
						if (cost_neighbor != -1)
							if ($nodes[node_neighbor]["COST"] == -1) || ($nodes[node_neighbor]["COST"] > ($nodes[current_node]["COST"] + cost_neighbor))
								$nodes[node_neighbor]["COST"] = $nodes[current_node]["COST"] + cost_neighbor
								STDERR.puts "Updated value for " + node_neighbor + " in " + $hostname
								STDERR.puts "Previous cost: " + $nodes[current_node]["COST"].to_s
								STDERR.puts "Cost to add: " + cost_neighbor.to_s
								STDERR.puts "New cost: " + ($nodes[current_node]["COST"] + cost_neighbor).to_s
							end
						end
					end
				end
			else
				# if current_node is the host, just add children since routing table is already available
				$nodes.keys.each do |node|
					if $nodes[node]["COST"] > 0
						stack.push(node)
					end
				end
			end
		end
		STDERR.puts $nodes
	end
end
=end

def status()

	# start with DFS to retrieve LSP from all other nodes
	stack = [$hostname]
	visited = []

	while !stack.empty?
		current_node = stack.pop
		if !visited.include? current_node
			visited.push(current_node)
			if current_node != $hostname
				if $nodes[current_node]["SOCKET"] != nil
					cost_string = ""
					lsp_string = ""
					ttl = 60
					#return_path = message_info[1]

					#STDERR.puts "return_path: " + return_path
					#STDERR.puts "socket: " + $nodes[return_node]["SOCKET"]

					#STDERR.puts "Received LSP request in " + $hostname + " from " + return_path.chomp(",")
					#return_nodes = return_path.split(",").chomp(",")
					#return_nodes = return_path.chomp(",").split(",")
					#STDERR.puts "return_nodes: " + return_nodes
					# return cost to all other nodes that are not the hostname

					$nodes.keys.each do |node|
						if node != $hostname
							cost_string += node + "," + $nodes[node]["COST"].to_s + ":"
						end
					end

					STDERR.puts "cost_string: " + cost_string

					#return_path += $hostname + ","
					#STDERR.puts "new_return: " + return_path

					# lsp = id sequencenum cost_string TTL return_path
					lsp_string = $hostname + " " + $sequencenum.to_s + " " + cost_string.chomp(":") + " " + ttl.to_s
					$lsp[$hostname]["NUM"] = $sequencenum
					$lsp[$hostname]["TTL"] = ttl
					neighbors = cost_string.chomp.strip.split(":")
					neighbors.each do |n|
						STDERR.puts "n: \"" + n + "\""

						node_cost = n.split(",")
						node_neighbor = node_cost[0]
						cost_neighbor = node_cost[1].to_i

						#STDERR.puts "neighbor: " + node_neighbor
						#STDERR.puts "cost: " + cost_neighbor.to_s

						$lsp[$hostname]["COST"][node_neighbor] = cost_neighbor
					end

					STDERR.puts $lsp
					$sequencenum = $sequencenum + 1

					STDERR.puts lsp_string

					socket = $nodes[current_node]["SOCKET"]
					#socket = TCPSocket.new($nodes[current_node]["IP"], $nodes[current_node]["PORT"])
					socket.write("LSP #{lsp_string} \0")
					STDERR.puts "LSP message sent to " + current_node

					dijkstras($hostname)
					#
					# # gets/recv/read do not seem to be reading the string back from the socket after using write
					# lsp_string = socket.gets("\0")
					# #cost_string = socket.read()
					# #cost_string = socket.recv_nonblock($maxPayload)
					# #cost_string = socket.recv(16)
					# socket.flush
					#
					# # code does not reach this point
					# STDERR.puts "lsp_string_recv: \"" + lsp_string + "\""
					#
					# STDERR.puts "Parsing lsp_string"
					# info = lsp_string.chomp.strip.split(" ")
					# id = info[0]
					# seqnum = info[1]
					# cost_string = info[2]
					# ttl = info[3]
					# return_path = info[4]
					#
					# STDERR.puts "\"" + id + "\""
					# STDERR.puts "\"" + seqnum.to_s + "\""
					# STDERR.puts "\"" + cost_string + "\""
					# STDERR.puts "\"" + ttl.to_s + "\""
					# STDERR.puts "\"" + return_path + "\""
					#
					# $lsp[id]["NUM"] = seqnum
					# $lsp[id]["TTL"] = ttl
					#
					# neighbors = cost_string.chomp.split(":")
					# STDERR.puts neighbors
					# neighbors.each do |n|
					# 	node_cost = n.split(",")
					# 	node_neighbor = node_cost[0]
					# 	cost_neighbor = node_cost[1].to_i
					# 	$lsp[id]["COST"][node_neighbor] = nil
					# 	$lsp[id]["COST"][node_neighbor] = cost_neighbor
					# end
					#
					# STDERR.puts $lsp

					# 	# STDERR.puts "neighbor: " + node_neighbor
					# 	# STDERR.puts "cost: " + cost_neighbor.to_s
					# 	# STDERR.puts node_neighbor.length > 0
					# 	# STDERR.puts node_neighbor.length > 1
					 	# add children of current_node to stack for processing
					# 	stack.push(node_neighbor)
					# 	# if route was previously unreachable (-1) or if new route has lower cost, update cost in host's routing table
					# 	STDERR.puts "current: " + current_node
					# 	if (cost_neighbor != -1)
					# 		if ($nodes[node_neighbor]["COST"] == -1) || ($nodes[node_neighbor]["COST"] > ($nodes[current_node]["COST"] + cost_neighbor))
					# 			$nodes[node_neighbor]["COST"] = $nodes[current_node]["COST"] + cost_neighbor
					# 			STDERR.puts "Updated value for " + node_neighbor + " in " + $hostname
					# 			STDERR.puts "Previous cost: " + $nodes[current_node]["COST"].to_s
					# 			STDERR.puts "Cost to add: " + cost_neighbor.to_s
					# 			STDERR.puts "New cost: " + ($nodes[current_node]["COST"] + cost_neighbor).to_s
					# 		end
					# 	end
					# end
				end
			else
				# if current_node is the host, just add children since routing table is already available
				$nodes.keys.each do |node|
					if $nodes[node]["COST"] > 0
						stack.push(node)
					end
				end
			end
		end
	end



	#since we would probably need to have an entry in the table for nodes that aren't
	#directly connected (like if we have a node n1 connected to n2 connected to n3 we would
	#need an entry for n3 in n1 dump table) I made some space here for a depth first (or breadth first)
	#search to get the cost. I would recommend sending a message to the other servers and getting info back
	#from them like this:

	# for each node do this
	# socket = $nodes[whatever node]["SOCKET"]
	# socket.send("COST {hostname (this is because the server needs a return address)}")

	#see the run_server method on what to do next



end


# --------------------- Part 2 --------------------- #
def sendmsg(cmd)
	STDOUT.puts "SENDMSG: not implemented"
end

def ping(cmd)
	STDOUT.puts "PING: not implemented"
end

def traceroute(cmd)
	STDOUT.puts "TRACEROUTE: not implemented"
end

def ftp(cmd)
	STDOUT.puts "FTP: not implemented"
end

# --------------------- Part 3 --------------------- #
def circuit(cmd)
	STDOUT.puts "CIRCUIT: not implemented"
end




# do main loop here....
def main()
	while(line = STDIN.gets())
		line = line.strip()
		arr = line.split(' ')
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
			status()
		when "SENDMSG"
			sendmsg(args)
		when "PING"
			ping(args)
		when "TRACEROUTE"
			traceroute(args)
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
		$table[node_name]["NEXT"] = nil
		$table[node_name]["COST"] = -1
		if node_name == $hostname
			$table[node_name]["COST"] = 0
		end
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

	#STDERR.puts $nodes
	# start separate server thread
	server_thread = Thread.new do
		run_server()
	end

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
