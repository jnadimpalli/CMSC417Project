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
				
				
				if message != nil
					message = message.chomp
					message_info = message.split(' ')
					
					message_type = message_info[0]
					
					case message_type
					# we have to create a symmetric connction to the other server
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
						
					# for this option a client is requesting that we return info about the cost to our neighbors
					when "COST"
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
	dst_socket.send("EDGEB #{$hostname} #{src_ip}\000", 0)
	
	#save destination socket so that you can send messages through here later
	$nodes[dst_name]["SOCKET"] = dst_socket
end

def dumptable(cmd)
  filename = cmd[0].split("./")[1]

  # for each node, check to see if a COST exists.
  # If so, add to file in order: src,dst,nextHop,distance
  $nodes.keys.each do |node|
	  
	#since we would probably need to have an entry in the table for nodes that aren't
	#directly connected (like if we have a node n1 connected to n2 connected to n3 we would
	#need an entry for n3 in n1 dump table) I made some space here for a depth first (or breadth first)
	#search to get the cost. I would recommend sending a message to the other servers and getting info back
	#from them like this:
	  
	# for each node do this 
	# socket = $nodes[whatever node]["SOCKET"]
	# socket.send("COST {hostname (this is because the server needs a return address)}")
	  
	#see the run_server method on what to do next
	  
	  
    if $nodes[node]["COST"] != nil
      File.open(filename, "w") {|f|
        f.write($hostname + "," + node + "," + node + "," + $nodes[node]["COST"].to_s + "\n")
      }
    end
  end
end

def shutdown(cmd)
  $server.close
  STDOUT.flush
  STDERR.flush
  exit(0)
end



# --------------------- Part 1 --------------------- # 
def edged(cmd)
	STDOUT.puts "EDGED: not implemented"
end

def edgeu(cmd)
	STDOUT.puts "EDGEu: not implemented"
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
			edgeU(args)
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

	#set up ports, server, buffers
	$socketToNode = {} #Hashmap to index node by socket

	# keep track of all nodes in hashtable
	fHandle = File.open(nodes)
	while(line = fHandle.gets())
		arr = line.chomp().split(',')
	
		node_name = arr[0]
		node_port = arr[1]

		$nodes[node_name] = {}
		$nodes[node_name]["PORT"] = node_port.to_i
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
