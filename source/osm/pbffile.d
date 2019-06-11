module osm.pbffile;

import OSMPBF.fileformat;
import OSMPBF.osmformat;
import google.protobuf;
import gfm.math.vector;
import std.typecons: Typedef;
import std.exception: enforce;
import std.bitmanip: bigEndianToNative;
import std.stdio: File;
debug(osmpbf) import std.stdio;

struct NativeBlob
{
    string type;
    ubyte[] data;
}

/// Returns: zero-sized blob data if no more blobs in file
private NativeBlob readBlob(File f)
{
    NativeBlob ret;

    // Read initial blob size:
    /// length of the BlobHeader message in network byte order
    ubyte[] blobHeaderLenNet = f.rawRead(new ubyte[4]); //const?

    if(blobHeaderLenNet.length == 0)
        return ret; // file end approached

    enforce(blobHeaderLenNet.length == 4, "file corrupted at latest blob");

    ubyte[4] bs = blobHeaderLenNet;
    auto BlobHeaderMsgSize = bs.bigEndianToNative!uint;
    enforce(BlobHeaderMsgSize > 0, "zero-sized blob");

    // Read blob header:
    auto bh_bytes = f.rawRead(new ubyte[BlobHeaderMsgSize]); //const?
    auto bh = bh_bytes.fromProtobuf!BlobHeader;

    ret.type = bh.type;

    // Read blob:
    auto b_bytes = f.rawRead(new ubyte[bh.datasize]);
    enforce(b_bytes.length == bh.datasize, "blob length mismatch");
    Blob blob = b_bytes.fromProtobuf!Blob;

    if(blob.rawSize == 0)
    {
        debug(osmpbf) writeln("raw block, size=", blob.raw.length);
        ret.data = blob.raw;
    }
    else
    {
        debug(osmpbf) writeln("zlib compressed block, size=", blob.rawSize);
        enforce(blob.zlibData.length > 0, "zlib block empty");

        import std.zlib: uncompress;

        ret.data = cast(ubyte[]) uncompress(blob.zlibData, blob.rawSize);
    }

    return ret;
}

HeaderBlock readOSMHeader(File f)
{
    auto hb = f.readBlob;

    enforce(hb.type == "OSMHeader", "\""~hb.type~"\" instead of OSMHeader");

    auto h = hb.data.fromProtobuf!HeaderBlock;

    debug(osmpbf)
    {
        writefln( "required_features=%s", h.required_features );
    }

    return h;
}

alias vec2l = vec2!long;
alias Coords = Typedef!(vec2l, vec2l.init, "OSM coords");
