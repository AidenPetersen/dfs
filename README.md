# Distributed P2P File Server

## Architecture
We 2 different executables in this project. The NameServer, and the FileServer. The NameServer handles the mapping between the FileServer names and process IDs (PID). 

## Requirements
This project is tested on elixir v1.16.3. There are no external dependencies.
telnet is needed to send messages to the FileServers

## Running

### NameServer
To run the NameServer, you should just be able to run
```bash
./start_nameserver.sh
```
This will launch an iex instance and will start the nameserver application.

### FileServer
Running the FileServer is more difficult, since these need to have names that will not overlap.
```
./start_fileserver.sh fs1
```
Will startup a fileserver with name fs1. It looks in the file `apps/file_server/fs1.iex.exs` to determine what arguments
to pass the application on startup. This file will have to be modified based on the hostname of the machine that the nameserver is on.
Currently the line 
```elixir
Node.connect(:name_server@nixbox)
```
will have to be changed to match your system. The only change needed will likely be chainging nixbox to the hostname of your system. The line

```elixir
FileServer.start([], ["../../testdir1", "fs1", 3030])
```

has a few fields

```elixir
FileServer.start([], ["<file_dir>", "<name>", <tcp_port>])
```
If you want to use a different folder to host files from, you will need to change the `file_dir` variable. The `name` should match the name used
in the shell script, and the `tcp_port` is the port you can connect to telnet from to send messages.

Once you change these files to match your system, you can run 
```bash
./start_fileserver <name>
```
which will look for the file `apps/file_server/<name>.iex.exs` to startup the application

When you are using multiple FileServers, each fileserver must have a different name. 

## Using the fileserver
You must connect to the fileserver via TCP to use it. I recommend using telnet. You can run
```
telnet 127.0.0.1 3030
```
To connect from one of the provided iex.exs files by default.
Once you are in telnet, there are a total of 6 commands you can use
1. `ls <dir> <server>`

    Lists files in `<dir>` on targeted `<server>` name
2. `get <src_file> <dst_file> <server>`
   
    Copies file from remote node to your node. `<src_file>` is the file on the remote node
3. `put <src_file> <dst_file>`
   
    Copies file from local node to remote node. `<dst_file>` is on the remote node
4. `read <path> <server>`
   
    Outputs file content to tcp from remote node
5. `del <path> <server>`
   
    Removes file from remote node
6. `stop`
7. 
    Stops the FileServer


### Reasons for error
There is a potential that a command will error. There are a lot of potential ways for a command to error, and a lot of things that could cause it.
Instead of implementing error checking, I decided to use the erlang methodology of "let it fail". If something fails, the server will gracefully terminate
itself, and it's supervisor will restart it. The FileServer is stateless, so nothing is lost, you will just lose your telnet connection, since if it stays up it will attempt to send the same error causing message to the server again

Here's a list of things that could cause an error
- You cannot use any commands on it's own server. This is an issue with the synchronous communication being used between servers. If elixir didn't have the self checking it would enter a deadlock, but it does not and just errors instead. It will reboot the
- If a command is used on a file that does not exist, it will error
- If a command is used on a remote server that doesn't exist, it will error