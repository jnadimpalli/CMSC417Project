require 'socket'

$port = nil
$hostname = nil

$server = nil

$nodes = {}

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
				# recv and read don't seem to work with write
				#message = client.recv
				#message = client.read()

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

					# for this option a client is requesting that we return info about the cost to our neighbors
					when "COST"
						STDERR.puts "In COST for " + $hostname
			            cost_string = ""
			            return_node = message_info[1]

						STDERR.puts "Received COST request in " + $hostname + " from " + return_node
						# return cost to all other nodes that are not the hostname
			            $nodes.keys.each do |node|
							if node != $hostname
					        	cost_string += node + "," + $nodes[node]["COST"].to_s + " "
					        end
						end

			            cost_string += "\000"
						STDERR.puts "cost_string1: " + cost_string


			            return_socket = $nodes[return_node]["SOCKET"]
						return_socket.flush
						return_socket.write(cost_string)
						return_socket.flush
						STDERR.puts "Writing cost_string to socket"

						# here is some example code for how this might look

						# return_node = message_info[1]

						#construct a single string with info on the cost of every neighboring node
						#could look like this "n1,1 n2,2 n3,-1 n4,1"

						#send that string back in a socket message like this
						# return_socket = $nodes[return_node]["SOCKET"]
						# return_socket.send("that string\000", 0)
						# IMPORTANT: must end the string with \000 because that tells
						# server to keep connection to socket open
					end
				end
				client.flush
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

	$nodes[$hostname]["IP"] = src_ip

	# connect to server and tell it who is connecting to it
	dst_socket = TCPSocket.new(dst_ip, dst_port)
	dst_socket.write("EDGEB #{$hostname} #{src_ip}\000")
	#dst_socket.send("EDGEB #{$hostname} #{src_ip}\000", 0)

	#save destination socket so that you can send messages through here later
	$nodes[dst_name]["SOCKET"] = dst_socket
	STDERR.puts "Client EDGEB complete at " + $hostname
end

def dumptable(cmd)
	stack = [$hostname]
	visited = []
	filename = cmd[0].split("./")[1]

	# perform DFS to find all possible routes
	while !stack.empty?
		current_node = stack.pop
		if !visited.include? current_node
			visited.push(current_node)
			STDERR.puts "Visited " + current_node
			# if current_node is not the host, request COST message to build routing table
			if current_node != $hostname
				if $nodes[current_node]["SOCKET"] != nil
					#socket = $nodes[current_node]["SOCKET"]
					socket = TCPSocket.new($nodes[current_node]["IP"], $nodes[current_node]["PORT"])
					#socket.send("COST #{$hostname}\000", 0)
					socket.write("COST #{$hostname}\000")
					STDERR.puts "COST message sent to " + current_node

					# gets/recv/read do not seem to be reading the string back from the socket after using write
					cost_string = socket.gets("\0")
					#cost_string = socket.read()
					#cost_string = socket.recv_nonblock($maxPayload)
					#cost_string = socket.recv(16)
					socket.flush

					# code does not reach this point
					STDERR.puts "cost_string2: " + cost_string

					STDERR.puts "Parsing cost_string"
					neighbors = cost_string.chomp.split(" ")
					neighbors.each do |n|
						node_cost = n.split(",")
						node_neighbor = node_cost[0]
						cost_neighbor = node_cost[1].to_i

						# add children of current_node to stack for processing
						stack.push(node_neighbor)

						# if route was previously unreachable (-1) or if new route has lower cost, update cost in host's routing table
						if ($nodes[node_neighbor]["COST"] == -1) || ($nodes[node_neighbor]["COST"] > ($nodes[current_node]["COST"] + cost_neighbor))
							$nodes[node_neighbor]["COST"] = $nodes[current_node]["COST"] + cost_neighbor
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
	min = Float::INFINITY

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

		$distance.keys.each do |node|
			if $istance[node] = min
				unvisited.delete(node)
				$nodes.keys.each do |neighbor|
					if $nodes[neighbor]["COST"] > 0
						temp = distance[node] + $nodes[neighbor]["COST"]
						if temp < distance[node]
							distance[neighbor] = temp
							prev[neighbor] = node
						end
					end
				end
			end
		end
	end
end

def status()
	STDOUT.puts "STATUS: not implemented"
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

	# start separate server thread
	server_thread = Thread.new do
		run_server()
	end

	#set up ports, server, buffers
	#$socketToNode = {} #Hashmap to index node by socket

	# keep track of all nodes in hashtable
	fHandle = File.open(nodes)
	while(line = fHandle.gets())
		arr = line.chomp().split(',')

		node_name = arr[0]
		node_port = arr[1]

		$nodes[node_name] = {}
		$nodes[node_name]["SOCKET"] = nil

		# originally thought that a TCPSocket could be opened with only a name and the system
		# would automatically change it but cannot find it in the documentation anymore.
		# Trying to do it while chaining COST message requests
		if (node_name != $hostname)
			#STDERR.puts "Setting up " + node_name + " for " + $hostname
			#socket = TCPSocket.new("1.1.1.1", node_port)
			#$nodes[node_name]["INFO"] = socket
		end
		$nodes[node_name]["PORT"] = node_port.to_i
		# 0 is self, -1 is unreachable (infinity)
		$nodes[node_name]["COST"] = -1
		if node_name == $hostname
			$nodes[node_name]["COST"] = 0
		end
	end

	#STDERR.puts $nodes

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
	#server_thread = Thread.new do
	#	run_server()
	#end

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
