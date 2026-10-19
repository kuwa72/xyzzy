CC = gcc
hello: hello.o util.o
	$(CC) -o hello hello.o util.o
hello.o: hello.c
	$(CC) -c hello.c
util.o: util.c util.h
	$(CC) -c util.c
clean:
	rm -f hello *.o
