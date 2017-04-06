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
	$server = TCPServer.open($port)
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
				# if there is a message that means we have to create a symmetric connction to the other server
				if message != nil
					message = message.chomp
					node_info = message.split(' ')
					node_name = node_info[0]
					node_ip = node_info[1]
					
					#update node info
					$nodes[node_name]["IP"] = node_ip
					$nodes[node_name]["COST"] = 1				
	
					dst_port = $nodes[node_name]["PORT"]
					dst_socket = TCPSocket.new(node_ip, dst_port)
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
	dst_socket.send("#{$hostname} #{src_ip}\000", 0)
end

def dumptable(cmd)
  filename = cmd[0].split("./")[1]

  # for each node, check to see if a COST exists.
  # If so, add to file in order: src,dst,nextHop,distance
  $nodes.keys.each do |node|
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
