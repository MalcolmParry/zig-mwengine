#!/bin/bash

cd "$(dirname $0)"
cd ..

src_dir="Test/src/Shaders"
out_dir="Test/res/Shaders"

find "$src_dir" -name "*.glsl" | while read -r src; do
	rel="${src#$src_dir/}"
	vertOut="$out_dir/$rel.vert.spv"
	fragOut="$out_dir/$rel.frag.spv"
	
	if [[ ! -f "$vertOut" || "$src" -nt "$vertOut" ]]; then
		mkdir -p "$(dirname "$vertOut")"
		echo "Compiling $src -> $vertOut"
		glslangValidator -S vert -D_VERTEX -V $src -o $vertOut

		mkdir -p "$(dirname "$fragOut")"
		echo "Compiling $src -> $fragOut"
		glslangValidator -S frag -D_PIXEL -V $src -o $fragOut
	else
		echo "Up to date: $src"
	fi
done
