Node.connect(:name_server@nixbox)
Process.sleep(1000)
FileServer.start([], ["../../testdir2", "fs2", 3031])
