import std.stdio;
import osm.pbffile;
import s2.s2coords;
import s2.s2point_index;
import s2.s2latlng;
import s2.s2closest_point_query;

int main(string[] args)
{
	if(args.length <= 1)
	{
		writeln("File not specified");
		return 1;
	}

	auto file = File(args[1], "r");
	auto pointsIdx = new S2PointIndex!ulong;
	size_t counter;

	PrimitivesHandlers hndlrs = {
		nodeHandler: (ref node, osmCoords, lazy tags)
		{
			auto coords2d = osmCoords.coords2float;
			auto point = S2LatLng.fromDegrees(coords2d.x, coords2d.y).toS2Point;

			if(tags.length > 0)
				pointsIdx.add(point, node.id);

			counter++;

			if(counter % 100000 == 0)
				writefln("proceed nodes count %d", counter);

			//~ "coords:%s n:%s tags: %s".writefln(coords.coords2float, node, tags);
		},
		//~ lineHandler: (h, lazy tags) { "line:%s tags: %s".writefln(h, tags); },
	};

	void exceptionHdlr(NonFatalOsmPbfException e){ e.msg.writeln; }

	readPbfFile(file, hndlrs, &exceptionHdlr);

	auto pointQuery = new S2ClosestPointQuery!ulong(pointsIdx);
	auto target = new S2ClosestPointQueryPointTarget(
			S2LatLng.fromDegrees(56.1654, 92.9834).toS2Point
		);
	auto results = pointQuery.findClosestPoint(target);

	results.writeln;

	return 0;
}
