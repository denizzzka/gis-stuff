module osm.util;

import osm.pbffile: NonFatalOsmPbfException;
import osm.tags;
import OSMPBF.osmformat;

///
struct Tags
{
    uint[] keys;
    uint[] values;
}

///
Tags[] decodeDenseTags(in int[] denseTags)
{
    Tags[] res;

    auto i = 0;
    while(i < denseTags.length)
    {
        Tags t;

        while(i < denseTags.length && denseTags[i] != 0)
        {
            import std.exception: enforce;

            enforce( denseTags[i] != 0 ); //TODO: add NonFatalOsmPbfException exception
            enforce( denseTags[i+1] != 0 );

            t.keys ~= denseTags[i];
            t.values ~= denseTags[i+1];

            i += 2;
        }

        ++i;
        res ~= t;
    }

    return res;
}

unittest
{
    int[] t = [ 1, 2, 0, 3, 4, 5, 6 ];
    Tags[] d = decodeDenseTags( t );

    assert( d[0].keys[0] == 1 );
    assert( d[0].values[0] == 2 );

    assert( d[1].keys[0] == 3 );
    assert( d[1].values[0] == 4 );

    assert( d[1].keys[1] == 5 );
    assert( d[1].values[1] == 6 );
}

///
package Node[] decodeDenseNodes(in DenseNodes dn)
{
    import std.exception: enforce;

    enforce!NonFatalOsmPbfException(dn.lat.length == dn.id.length);
    enforce!NonFatalOsmPbfException(dn.lon.length == dn.id.length);

    auto tags = decodeDenseTags(dn.keysVals);
    //TODO: implement (lazy?) decoding of DenseInfo

    auto ret = new Node[dn.id.length];

    Node curr;

    foreach(i, _; ret)
    {
        // decode delta
        curr.id += dn.id[i];
        curr.lat += dn.lat[i];
        curr.lon += dn.lon[i];

        if(tags.length > 0 && tags[i].keys.length > 0)
        {
            curr.keys = tags[i].keys;
            curr.vals = tags[i].values;
        }
        else
        {
            curr.keys = null;
            curr.vals = null;
        }

        ret[i] = curr;
    }

    return ret;
}

alias OSM_id = long; ///

///
struct DecodedLine
{
    OSM_id[] coords_idx;

    invariant()
    {
        assert( coords_idx.length >= 2 );
    }

    string toString() const
    {
        import std.format;

        return format("nodes:%s", coords_idx);
    }
}

///
package DecodedLine decodeWay(in PrimitiveBlock prim, Way way)
{
    import std.conv: to;

    if(way.refs.length < 2)
        throw new NonFatalOsmPbfException("too short way (nodes number: "~way.refs.length.to!string~")");

    DecodedLine res;

    // decode index delta
    OSM_id curr = 0;
    foreach( c; way.refs )
    {
        curr += c;
        res.coords_idx ~= curr;
    }

    return res;
}
