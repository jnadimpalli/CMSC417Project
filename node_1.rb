require 'socket'

$port = nil
$hostname = nil

$server = nil

$nodes = {}

$lsp = {}
$sequencenum = 1

$table = {}

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

		listening_thread = Thread.new do
			read.each do |socket|
				if socket == $server
					# A new client is connecting to server
					client, addr_info = $server.accept_nonblock
					reading.push(client)

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

							if seqnum > $lsp[id]["NUM"]
								$lsp[id]["NUM"] = seqnum
								$lsp[id]["TTL"] = ttl

								neighbors = cost_string.chomp.strip.split(":")
								neighbors.each do |n|
									node_cost = n.split(",")
									node_neighbor = node_cost[0]
									cost_neighbor = node_cost[1].to_i

									$lsp[id]["COST"][node_neighbor] = cost_neighbor
								end

								new_ttl = ttl -1

								new_message = "LSP " + id + " " + (seqnum).to_s + " " + cost_string + " " + (new_ttl).to_s + " " + $hostname

								$nodes.keys.each do |node|
									if node != sender && $nodes[node]["SOCKET"] != nil && new_ttl >= 0
										socket = $nodes[node]["SOCKET"]
										socket.write("#{new_message} \0")
									end
								end

								lsp()

							end
						end
					end
					client.flush
				else
					# Perform a blocking-read until new-line is encountered.
					# We know the client is writing, so as long as it adheres to the
					# new-line protocol, we shouldn't block for very long.

					message = socket.gets("\0")
					message = message.chomp
					message_info = message.split(' ')

					message_type = message_info[0]

					case message_type
					when "LSP"
						id = message_info[1]
						seqnum = message_info[2].to_i
						cost_string = message_info[3]
						ttl = message_info[4].to_i
						sender = message_info[5]

						if seqnum > $lsp[id]["NUM"]
							$lsp[id]["NUM"] = seqnum
							$lsp[id]["TTL"] = ttl

							neighbors = cost_string.chomp.strip.split(":")
							neighbors.each do |n|
								node_cost = n.split(",")
								node_neighbor = node_cost[0]
								cost_neighbor = node_cost[1].to_i

								$lsp[id]["COST"][node_neighbor] = cost_neighbor
							end

							new_ttl = ttl -1

							new_message = "LSP " + id + " " + (seqnum).to_s + " " + cost_string + " " + (new_ttl).to_s + " " + $hostname

							$nodes.keys.each do |node|
								if node != sender && $nodes[node]["SOCKET"] != nil && node != id && new_ttl >= 0
									socket = $nodes[node]["SOCKET"]
									socket.write("#{new_message} \0")
								end
							end

							lsp()

						end
					end
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

	nodes_list = []

	STDOUT.puts "Name: #{$hostname}"
	STDOUT.puts "Port: #{$nodes[$hostname]["PORT"]}"

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

	$lsp[$hostname]["NUM"] = $sequencenum
	$lsp[$hostname]["TTL"] = 60
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

# def test()
# 	dijkstras($hostname)
# 	STDERR.puts "$nodes"
# 	STDERR.puts $nodes
# 	STDERR.puts "$lsp"
# 	STDERR.puts $lsp
# 	STDERR.puts "$table"
# 	STDERR.puts $table
# end



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
			lsp()
		when "SENDMSG"
			sendmsg(args)
		when "PING"
			ping(args)
		when "TRACEROUTE"
			traceroute(args)
	#	when "TEST"
	#		test()
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
	end

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
