test: main.o Account.o Type.o search.o stl_to_sql.o sqlite3.o
	g++ -W -g main.o Account.o Type.o search.o stl_to_sql.o sqlite3.o -o test

main.o: main.cpp Account.h sqlite3.h
	g++ -W -g -c main.cpp

stl_to_sql.o: stl_to_sql.c stl_to_sql.h sqlite3.h bridge.h
	gcc -W -g -c stl_to_sql.c

sqlite3.o: sqlite3.c sqlite3.h
	gcc -W -g -c sqlite3.c

search.o: search.cpp search.h sqlite3.h bridge.h Account.h Type.h
	g++ -W -g -c search.cpp

Account.o: Account.cpp Account.h
	g++ -W -g -c Account.cpp

Type.o: Type.cpp Type.h
	g++ -W -g -c Type.cpp