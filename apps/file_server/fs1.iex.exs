Node.connect(:name_server@nixbox)
Process.sleep(1000)
FileServer.start([], ["../../testdir1", "fs1", 3030])
