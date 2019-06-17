import std.stdio;
import osm.pbffile;

int main(string[] args)
{
	if(args.length <= 1)
	{
		writeln("File not specified");
		return 1;
	}

	auto file = File(args[1], "r");

	PrimitivesHandlers hndlrs = {
		nodeHandler: (ref node, coords, lazy tags) { "coords:%s n:%s tags: %s".writefln(coords.coords2float, node, tags); },
		//~ lineHandler: (h, lazy tags) { "line:%s tags: %s".writefln(h, tags); },
	};

	void exceptionHdlr(NonFatalOsmPbfException e){ e.msg.writeln; }

	readPbfFile(file, hndlrs, &exceptionHdlr);

	return 0;
}
