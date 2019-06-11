module osm.pbffile;

public import osm.util;

import OSMPBF.fileformat;
import OSMPBF.osmformat;
import google.protobuf;
import std.exception;
import std.stdio: File;
debug(osmpbf) import std.stdio;
import std.functional: toDelegate;

///
struct PrimitivesHandlers
{
    void delegate(Node) nodeHandler;
    void delegate(DecodedLine) lineHandler;
}

/// Just throws exception
void defaultExceptionHandler(NonFatalOsmPbfException e)
{
    throw e;
}

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

            debug(osmpbf_verbose) writefln("lat_offset=%d lon_offset=%d", prim.lat_offset, prim.lon_offset);
            debug(osmpbf_verbose) writeln("granularity=", prim.granularity);

            with(handlers)
            foreach(ref grp; prim.primitivegroup)
            {
                foreach(ref node; grp.nodes)
                    if(nodeHandler)
                        nodeHandler(node);

                //~ if(!grp.dense.isNull)
                //~ {
                    //~ auto nodes = decodeDenseNodes(grp.dense);

                    //~ foreach(ref node; nodes)
                        //~ if(nodeHandler)
                            //~ nodeHandler(node);
                //~ }

                foreach(ref way; grp.ways)
                    if(lineHandler)
                        lineHandler(decodeWay(prim, way));
            }
        }
        catch(NonFatalOsmPbfException e)
            exceptionHandlerDg(e);
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

private:

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
        writefln( "required_features=%s", h.required_features );
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
