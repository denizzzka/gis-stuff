module osm.pbffile;

public import osm.util;

import osm.tags;
import OSMPBF.fileformat;
import OSMPBF.osmformat;
import google.protobuf;
import std.exception;
import std.stdio: File;
debug(osmpbf) import std.stdio;
import std.functional: toDelegate;
import gfm.math.vector: vec2;

///
struct PrimitivesHandlers
{
    void delegate(ref Node, OsmCoords coords, lazy const Tag[]) nodeHandler;
    void delegate(DecodedLine, lazy const Tag[]) lineHandler;
}

/// Just throws exception
void defaultExceptionHandler(NonFatalOsmPbfException e)
{
    throw e;
}

alias OsmCoords = vec2!long;
alias FloatLatLon = vec2!real;

///
void readPbfFile(
    File file,
    PrimitivesHandlers handlers,
    void delegate(NonFatalOsmPbfException) exceptionHandlerDg = toDelegate(&defaultExceptionHandler)
)
{
    file.readOSMHeader; // skip HeaderBlock

    while(true)
    {
        PrimitiveBlock prim;

        try
        {
            auto data = file.readOSMData;

            if(data.length == 0) // end of file?
                break;

            prim = data.fromProtobuf!PrimitiveBlock;
        }
        catch(NonFatalOsmPbfException e)
            exceptionHandlerDg(e);

        if(prim.granularity == 0)
            prim.granularity = 100; // set to default

        debug(osmpbf_verbose) writefln("lat_offset=%d lon_offset=%d", prim.latOffset, prim.lonOffset);
        debug(osmpbf_verbose) writefln("granularity=%d", prim.granularity);

        with(handlers)
        foreach(ref grp; prim.primitivegroup)
        {
            try
            {
                if(nodeHandler)
                {
                    foreach(ref node; grp.nodes)
                    {
                        nodeHandler(
                            node,
                            prim.decodeGranularCoords(node),
                            prim.stringtable.getTags(node.keys, node.vals)
                        );
                    }

                    // TODO: Potentially incorrect check
                    // More: https://github.com/dcarp/protobuf-d/issues/21
                    if(grp.dense != protoDefaultValue!DenseNodes)
                    {
                        auto nodes = grp.dense.decodeDenseNodes;

                        foreach(ref node; nodes)
                            nodeHandler(
                                node,
                                prim.decodeGranularCoords(node),
                                prim.stringtable.getTags(node.keys, node.vals)
                            );
                    }
                }

                if(lineHandler)
                    foreach(ref way; grp.ways)
                        lineHandler(decodeWay(prim, way), prim.stringtable.getTags(way.keys, way.vals));
            }
            catch(NonFatalOsmPbfException e)
                exceptionHandlerDg(e);
        }
    }
}

/// Non-fatal parsing exception
class NonFatalOsmPbfException : Exception
{
  ///
  this(string msg, string file = __FILE__, size_t line = __LINE__) pure @safe
  {
    super(
      msg,
      file,
      line
    );
  }
}

/// Decode OSM coords into floating
auto coords2float(in OsmCoords c) pure
{
    return FloatLatLon(.000_000_001f * c.x,  .000_000_001f * c.y);
}

private:

OsmCoords decodeGranularCoords(in PrimitiveBlock pb, in Node n) pure
{
    OsmCoords r;

    r.x = pb.latOffset + pb.granularity * n.lat;
    r.y = pb.lonOffset + pb.granularity * n.lon;

    return r;
}

struct NativeBlob
{
    string type;
    ubyte[] data;
}

/// Returns: zero-sized blob data if no more blobs in file
NativeBlob readBlob(File f)
{
    import std.bitmanip: bigEndianToNative;

    NativeBlob ret;

    // Read initial blob size:
    /// length of the BlobHeader message in network byte order
    ubyte[] blobHeaderLenNet = f.rawRead(new ubyte[4]); //const?

    if(blobHeaderLenNet.length == 0)
        return ret; // file end approached

    enforce!NonFatalOsmPbfException(blobHeaderLenNet.length == 4, "file corrupted at latest blob");

    ubyte[4] bs = blobHeaderLenNet;
    auto BlobHeaderMsgSize = bs.bigEndianToNative!uint;
    enforce!NonFatalOsmPbfException(BlobHeaderMsgSize > 0, "zero-sized blob");

    // Read blob header:
    auto bh_bytes = f.rawRead(new ubyte[BlobHeaderMsgSize]); //const?
    auto bh = bh_bytes.fromProtobuf!BlobHeader;

    ret.type = bh.type;

    // Read blob:
    auto b_bytes = f.rawRead(new ubyte[bh.datasize]);
    enforce!NonFatalOsmPbfException(b_bytes.length == bh.datasize, "blob length mismatch");
    Blob blob = b_bytes.fromProtobuf!Blob;

    if(blob.rawSize == 0)
    {
        debug(osmpbf) writeln("raw block, size=", blob.raw.length);
        ret.data = blob.raw;
    }
    else
    {
        debug(osmpbf) writeln("zlib compressed block, size=", blob.rawSize);
        enforce!NonFatalOsmPbfException(blob.zlibData.length > 0, "zlib block empty");

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
        writefln("required_features=%s", h.requiredFeatures);
    }

    return h;
}

ubyte[] readOSMData(File f)
{
    auto b = f.readBlob;

    if(b.data.length != 0)
        enforce(b.type == "OSMData", "\""~b.type~"\" instead of OSMData" );

    return b.data;
}
