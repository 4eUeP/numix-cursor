build:
	bash ./build.sh

install-user:
	mkdir -p ~/.icons/Numix-Cursor
	cp -R ./build/dist ~/.icons/Numix-Cursor

clean:
	rm -rf ./build
