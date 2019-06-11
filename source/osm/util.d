module osm.util;

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

            enforce( denseTags[i] != 0 );
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

Node[] decodeDenseNodes(in DenseNodes dn)
{
    auto ret = new Node[dn.id.length];

    auto tags = decodeDenseTags(dn.keysVals);

    Node curr;

    foreach(i, c; dn.id)
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
