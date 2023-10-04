default:
	as main.s --strip-local-absolute -O2 -ad -o main.o
	ld main.o -O -s --relax --no-demangle --gc-sections --print-gc-sections --strip-discarded --compress-debug-sections=zlib -o main
