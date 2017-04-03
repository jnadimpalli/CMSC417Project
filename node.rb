require 'socket'

$port = nil
$hostname = nil

$server = nil

$nodes = {}
$index = nil

$updateInterval = nil
$maxPayload = nil
$pingTimeout = nil


# --------------------- Part 0 --------------------- # 

def edgeb(cmd)
	src_ip = cmd[0]
	dst_ip = cmd[1]

	dst_name = cmd[2]
	dst_port = $nodes[dst_name]["PORT"]
	

	#update cost
	$nodes[dst_name]["COST"] = 1

	#dst_socket = TCPSocket.new(dst_ip, dst_port)

	STDOUT.puts "Program entered edgeb method. Method still in developement"
	
end

def dumptable(cmd)
	STDOUT.puts "DUMPTABLE: not implemented"
end

def shutdown(cmd)
	STDOUT.puts "SHUTDOWN: not implemented"
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
	
	counter = 0
	fHandle = File.open(nodes)
	while(line = fHandle.gets())
		arr = line.chomp().split(',')
	
		node_name = arr[0]
		node_port = arr[1]

		if node_name == hostname
			$index = counter
		end

		$nodes[node_name] = {}
		$nodes[node_name]["PORT"] = node_port
		counter += counter
	end

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

	

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
