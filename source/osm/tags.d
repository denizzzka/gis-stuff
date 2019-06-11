module osm.tags;

import OSMPBF.osmformat;
import std.conv: to;

///
struct Tag
{
    string key;
    string value;

    string toString() const
    {
        return key~"="~value;
    }
}

package Tag[] getTags(in StringTable stringtable, in uint[] keys, in uint[] values)
in(keys.length == values.length)
{
    Tag[] res;

    foreach( i, c; keys )
        res ~= stringtable.getTag(keys[i], values[i]);

    return res;
}

private Tag getTag(in StringTable stringtable, in uint key, in uint value)
{
    return Tag(
            getStringByIndex(stringtable, key),
            getStringByIndex(stringtable, value)
        );
}

private string getStringByIndex(in StringTable stringtable, in uint index)
{
    char[] res;

    if(stringtable.s.length != 0)
        res = cast(char[]) stringtable.s[index];

    return res.to!string;
}
